import type { ASTNode, NodeType } from '../../types';
import { parseMarkdown, type WebMd4cFlags } from '../../parseMarkdown';
import { completeMarkdown } from './InputRemend';
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

// A source paragraph break: a newline followed by one or more blank lines.
const PARAGRAPH_BREAK_RE = /\n[ \t]*(?:\n[ \t]*)+/g;

function countNewlines(text: string): number {
  return text.split('\n').length - 1;
}

// Bare URLs stay plain text until the autolink layer claims them.
const INPUT_PARSE_FLAGS: WebMd4cFlags = {
  underline: true,
  latexMath: false,
  superscript: false,
  subscript: false,
  highlight: false,
  hardSoftBreaks: false,
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

// A heading maps to its per-level block type; an out-of-range level falls
// back to paragraph so a malformed parse degrades gracefully rather than
// dropping the line. List items are recognized here but emitted with their
// own per-line bounds and AST-derived depth in the walk, not via the generic
// emission.
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
  blankRuns: number[];
  blankRunIndex: number;
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

// Builds the input model from an already-parsed AST. Ordinals are left at
// their placeholder value — BlockStore.setRanges recomputes them.
export function parseResultFromAst(
  ast: ASTNode,
  completedMarkdown: string
): ParseResult {
  // md4c collapses any blank-line run into a single break; re-read the real
  // runs from the source so each break replays its original newline count.
  const blankRuns = [
    ...completedMarkdown.trim().matchAll(PARAGRAPH_BREAK_RE),
  ].map((match) => countNewlines(match[0]));

  const state: WalkState = {
    text: '',
    formattingRanges: [],
    blockRanges: [],
    activeStyles: [],
    blankRuns,
    blankRunIndex: 0,
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

  // A list node increments the nesting depth of its items, so an item's depth
  // is (enclosing list nodes - 1). Depth comes from this AST nesting, never
  // from counting leading spaces.
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

  const children = node.children ?? [];
  for (let index = 0; index < children.length; index++) {
    const child = children[index]!;
    // md4c emits no separators, so a block that follows a sibling starts a
    // new line here. Between top-level blocks, replay the source's blank
    // lines (md4c drops them); inside a list, items, a sublist, or an item's
    // further paragraphs each take a single newline. An empty item's sublist
    // is its first child but still starts below the item's own (empty) line.
    const startsLine =
      index > 0 || (node.type === 'ListItem' && isListNode(child));
    if (startsLine && BLOCK_NODE_TYPES.has(child.type)) {
      if (childListDepth > 0) {
        append(state, '\n');
      } else if (state.text.length > 0) {
        const run = state.blankRuns[state.blankRunIndex++];
        append(state, '\n'.repeat(run ?? 2));
      }
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

  // Emit the block range for handler-claimed block types only; paragraph
  // (the implicit default) yields nothing, and list items were emitted above
  // with their own line bounds.
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

// `complete: false` skips InputRemend's completion of unclosed delimiters,
// which serves half-typed or truncated documents. A fragment being inserted
// (`insertText`, a paste) is neither, and completing it would read the lone
// `_` of `snake_case` as an opener and close it (#1014).
export async function parseToPlainTextAndRanges(
  markdown: string,
  { complete = true }: { complete?: boolean } = {}
): Promise<ParseResult> {
  if (markdown.length === 0) {
    return { plainText: '', formattingRanges: [], blockRanges: [] };
  }

  const completed = complete ? completeMarkdown(markdown) : markdown;
  let ast: ASTNode;
  try {
    ast = await parseMarkdown(completed, INPUT_PARSE_FLAGS);
  } catch {
    // A failed parse degrades to unformatted text rather than crashing.
    return { plainText: markdown, formattingRanges: [], blockRanges: [] };
  }
  return parseResultFromAst(ast, completed);
}
