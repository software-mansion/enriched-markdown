import type { ASTNode, NodeType } from '../../types';
import { parseMarkdown, type WebMd4cFlags } from '../../parseMarkdown';
import {
  normalizeBlockRanges,
  normalizeFormattingRanges,
} from './normalizeImport';
import {
  blockTypeForHeadingLevel,
  createBlockRange,
  LIST_ITEM_BLOCK_TYPES,
  MAX_LIST_DEPTH,
  type BlockRange,
  type BlockType,
} from '../model/blocks';
import {
  createFormattingRange,
  type FormattingRange,
  type InputStyleType,
} from '../model/inlineStyles';
import { clamp } from '../utils';

export interface ParseResult {
  plainText: string;
  formattingRanges: FormattingRange[];
  blockRanges: BlockRange[];
}

// Bare URLs stay plain text until the autolink layer claims them.
const INPUT_PARSE_FLAGS: WebMd4cFlags = {
  underline: true,
  latexMath: false,
  superscript: false,
  subscript: false,
  highlight: false,
  hardSoftBreaks: false,
  // Blank lines come back as BlankLine nodes where they stood, so each one
  // replays as an empty line of its own (see `pendingBlankLines`).
  preserveBlankLines: true,
  permissiveAutolinks: false,
};

const STYLE_NODE_TYPES: Partial<Record<NodeType, InputStyleType>> = {
  Strong: 'strong',
  Emphasis: 'em',
  Underline: 'underline',
  Strikethrough: 'strikethrough',
  Link: 'link',
  Spoiler: 'spoiler',
};

const BLOCK_NODE_TYPES = new Set<NodeType>([
  'Paragraph',
  'Heading',
  'Blockquote',
  'UnorderedList',
  'OrderedList',
  'ListItem',
  'CodeBlock',
  'ThematicBreak',
  'Table',
  'LatexMathDisplay',
]);

// An out-of-range heading level falls back to paragraph rather than dropping
// the line. List items are emitted by the walk with their own per-line bounds
// and AST-derived depth, not via the generic emission.
function nodeTypeToBlockType(
  nodeType: NodeType,
  level: number
): BlockType | null {
  switch (nodeType) {
    case 'Paragraph':
      return 'paragraph';
    case 'Heading':
      return blockTypeForHeadingLevel(level) ?? 'paragraph';
    case 'ListItem':
      return 'unordered-list-item';
    default:
      return null;
  }
}

interface ActiveStyle {
  type: InputStyleType;
  startPosition: number;
  url: string | undefined;
}

// A list item's range covers its first line; the end is set when the walk
// appends the first newline after the item starts.
interface ItemLine {
  lineEnd: number;
}

// The walk only ever appends to `text`, never reads it back: on V8, reading
// (endsWith, indexOf) flattens the growing rope, and doing that per list item
// made the walk quadratic. Positions come from `text.length` only.
interface WalkState {
  text: string;
  formattingRanges: FormattingRange[];
  blockRanges: BlockRange[];
  activeStyles: ActiveStyle[];
  // Blank source lines seen since the last block, written out as empty lines
  // when the next block starts. Deferred so trailing ones are dropped, as
  // leading ones are, rather than leaving empty lines at the end.
  pendingBlankLines: number;
  // Open list items whose first line has not ended yet.
  pendingItemLines: ItemLine[];
}

function append(state: WalkState, chunk: string): void {
  // Scan the incoming chunk, not the accumulated text.
  const newline = chunk.indexOf('\n');
  if (newline >= 0 && state.pendingItemLines.length > 0) {
    const lineEnd = state.text.length + newline;
    for (const item of state.pendingItemLines) {
      item.lineEnd = lineEnd;
    }
    state.pendingItemLines.length = 0;
  }
  state.text += chunk;
}

// Ordinals are left at their placeholder value; BlockStore.setRanges
// recomputes them.
export function parseResultFromAst(ast: ASTNode): ParseResult {
  const state: WalkState = {
    text: '',
    formattingRanges: [],
    blockRanges: [],
    activeStyles: [],
    pendingBlankLines: 0,
    pendingItemLines: [],
  };
  walkNode(ast, state, 0, false);

  return {
    plainText: state.text,
    formattingRanges: normalizeFormattingRanges(state.formattingRanges),
    blockRanges: normalizeBlockRanges(state.text, state.blockRanges),
  };
}

function isListNode(node: ASTNode): boolean {
  return node.type === 'UnorderedList' || node.type === 'OrderedList';
}

// A code block's text ends with the newline that closes its last line. The
// input has no code block, so its lines are kept as plain lines, and that
// newline would add one more: an empty line after the block on import, a line
// split when one is pasted mid-line. Block boundaries are written by the walk.
function withoutClosingNewline(children: ASTNode[]): ASTNode[] {
  const last = children[children.length - 1];
  if (last?.type !== 'Text' || !last.content?.endsWith('\n')) {
    return children;
  }
  return [
    ...children.slice(0, -1),
    { ...last, content: last.content.slice(0, -1) },
  ];
}

function blankLineCount(node: ASTNode): number {
  const count = parseInt(node.attributes?.count ?? '', 10);
  return Number.isNaN(count) ? 1 : count;
}

function walkNode(
  node: ASTNode,
  state: WalkState,
  listDepth: number,
  orderedContainer: boolean
): void {
  const styleType = STYLE_NODE_TYPES[node.type] ?? null;

  if (styleType !== null) {
    const url = styleType === 'link' ? node.attributes?.url : undefined;
    state.activeStyles.push({
      type: styleType,
      startPosition: state.text.length,
      url,
    });
  }

  // Depth comes from AST nesting, never from counting leading spaces.
  const isListContainer = isListNode(node);
  const childListDepth = isListContainer ? listDepth + 1 : listDepth;
  const childOrdered = isListContainer
    ? node.type === 'OrderedList'
    : orderedContainer;

  const itemStart = node.type === 'ListItem' ? state.text.length : -1;
  const itemLine: ItemLine | null = itemStart >= 0 ? { lineEnd: -1 } : null;
  if (itemLine !== null) {
    state.pendingItemLines.push(itemLine);
  }

  const parsedLevel = parseInt(node.attributes?.level ?? '', 10);
  const blockLevel = Number.isNaN(parsedLevel) ? 0 : parsedLevel;
  const blockType = nodeTypeToBlockType(node.type, blockLevel);
  const blockStartPosition = state.text.length;

  if (node.type === 'Text') {
    append(state, node.content ?? '');
  } else if (node.type === 'LineBreak' || node.type === 'SoftBreak') {
    append(state, '\n');
  }

  const children =
    node.type === 'CodeBlock'
      ? withoutClosingNewline(node.children ?? [])
      : (node.children ?? []);
  for (let index = 0; index < children.length; index++) {
    const child = children[index]!;
    if (child.type === 'BlankLine') {
      // An empty item reports its own line as a blank one, first in the item;
      // only the lines past it are blank lines between blocks.
      const ownLine = node.type === 'ListItem' && index === 0 ? 1 : 0;
      state.pendingBlankLines += Math.max(0, blankLineCount(child) - ownLine);
      continue;
    }
    // md4c emits no separators, so a block that follows a sibling starts a
    // new line here, after an empty line for each blank source line between
    // them - top-level or inside a list alike, so "- a\n\n- b" keeps its
    // blank line and every later one stays where it was. An empty item's
    // sublist is its first child but still starts below the item's own
    // (empty) line. Blank lines before the first block are dropped.
    const startsLine =
      index > 0 || (node.type === 'ListItem' && isListNode(child));
    if (startsLine && BLOCK_NODE_TYPES.has(child.type)) {
      // The block store clamps an item to one level below the item right
      // above it, so an empty line above a nested item would de-nest it:
      // the blank line is the smaller loss.
      const startsNestedItem =
        (child.type === 'ListItem' && childListDepth > 1) ||
        (node.type === 'ListItem' && isListNode(child));
      if (startsNestedItem) {
        state.pendingBlankLines = 0;
      }
      if (childListDepth > 0 || state.text.length > 0) {
        append(state, '\n'.repeat(1 + state.pendingBlankLines));
      }
      state.pendingBlankLines = 0;
    }
    walkNode(child, state, childListDepth, childOrdered);
  }

  // A list item owns its own first line; a nested sublist lives on later
  // lines, so the item's range ends at the first newline after its start.
  // An empty item keeps a zero-length range, BlockStore's empty-line anchor.
  if (itemLine !== null) {
    let lineEnd = itemLine.lineEnd;
    if (lineEnd < 0) {
      // No newline since the item started: its nested items have already
      // exited, so it is the last pending entry.
      state.pendingItemLines.pop();
      lineEnd = state.text.length;
    }
    // The item sees listDepth already incremented by its enclosing list
    // node, so its 0-based depth is listDepth - 1.
    const depth = clamp(listDepth - 1, 0, MAX_LIST_DEPTH);
    const itemType: BlockType = orderedContainer
      ? 'ordered-list-item'
      : 'unordered-list-item';
    state.blockRanges.push(
      createBlockRange(itemType, itemStart, lineEnd, depth)
    );
  }

  if (styleType !== null) {
    const activeStyle = state.activeStyles.pop()!;
    const end = state.text.length;
    if (end > activeStyle.startPosition) {
      state.formattingRanges.push(
        createFormattingRange(
          styleType,
          activeStyle.startPosition,
          end,
          activeStyle.url
        )
      );
    }
  }

  // Paragraph is the implicit default; list items were emitted above with
  // their own line bounds.
  if (
    blockType !== null &&
    blockType !== 'paragraph' &&
    !LIST_ITEM_BLOCK_TYPES.has(blockType)
  ) {
    const end = state.text.length;
    if (end > blockStartPosition) {
      state.blockRanges.push(
        createBlockRange(blockType, blockStartPosition, end, blockLevel)
      );
    }
  }
}

// The markdown is parsed as given: an unclosed delimiter stays literal text.
// Completing it first would turn the lone `_` of `snake_case`, the `*` of
// `2*3` or a `[` into formatting or into text the caller never passed. iOS
// completes but then drops every range whose closer it appended, which comes
// to the same result.
export async function parseToPlainTextAndRanges(
  markdown: string
): Promise<ParseResult> {
  if (markdown.length === 0) {
    return { plainText: '', formattingRanges: [], blockRanges: [] };
  }

  let ast: ASTNode;
  try {
    ast = await parseMarkdown(
      protectLeadingWhitespace(markdown),
      INPUT_PARSE_FLAGS
    );
  } catch {
    return { plainText: markdown, formattingRanges: [], blockRanges: [] };
  }
  const result = parseResultFromAst(ast);
  return {
    ...result,
    plainText: restoreLeadingWhitespace(result.plainText),
  };
}

// Leading whitespace is kept as text, as iOS does and as the serializer writes
// it, instead of being dropped (up to three spaces) or opening an indented code
// block (a tab or a fourth space). md4c has no switch for that, so each tab and
// space of the run is swapped one for one with a private-use stand-in it reads
// as text, and swapped back in the plain text afterwards: offsets never move.
// Whitespace that is structure stays as it is - the indent in front of a list,
// heading or quote marker - and so does the one separator after a list or
// heading marker; whitespace past that is the line's text. A line of only
// whitespace stays blank.
const TAB_STAND_IN = '\uE000';
const SPACE_STAND_IN = '\uE001';
const STAND_IN_RUN_RE = /^[\uE000\uE001]+/gm;

// `[indent][marker][separator][text]`: a bullet, an ordered "1." / "1)" or an
// ATX "#", each needing a separator or the line end, or a quote's ">".
const LINE_RE =
  /^([ \t]*)(?:([-+*]|\d{1,9}[.)]|#{1,6})([ \t]|$)|(>))?([ \t]*)(.*)$/;

function standIns(whitespace: string): string {
  return whitespace.replace(/[ \t]/g, (c) =>
    c === '\t' ? TAB_STAND_IN : SPACE_STAND_IN
  );
}

function protectLeadingWhitespace(markdown: string): string {
  if (!/(^|\n)[ \t]|[-+*#)>.][ \t][ \t]/.test(markdown)) {
    return markdown;
  }
  return markdown
    .split('\n')
    .map((line) => {
      const match = LINE_RE.exec(line);
      if (match === null) {
        return line;
      }
      const [, indent, marker, separator, quote, rest, content] = match;
      if (content === '') {
        return line;
      }
      if (marker === undefined && quote === undefined) {
        return standIns(indent! + rest!) + content;
      }
      if (quote !== undefined) {
        return line;
      }
      return indent! + marker + separator + standIns(rest!) + content;
    })
    .join('\n');
}

function restoreLeadingWhitespace(text: string): string {
  return text.replace(STAND_IN_RUN_RE, (run) =>
    run.replace(/./g, (c) => (c === TAB_STAND_IN ? '\t' : ' '))
  );
}
