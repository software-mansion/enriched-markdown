import type { ASTNode, NodeType } from '../../types';
import { parseMarkdown } from '../../parseMarkdown';
import { completeMarkdown } from './InputRemend';
import { stripZwsp } from './MarkdownSerializer';
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

// The input dialect: `_x_` is underline (not emphasis), bare URLs stay plain
// text until the autolink layer claims them.
const INPUT_PARSE_FLAGS = {
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

const TOP_LEVEL_BLOCK_TYPES = new Set<NodeType>([
  'Paragraph',
  'Heading',
  'Blockquote',
  'UnorderedList',
  'OrderedList',
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

interface WalkState {
  text: string;
  formattingRanges: FormattingRange[];
  blockRanges: BlockRange[];
  activeStyles: ActiveStyle[];
  blankRuns: number[];
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
  };
  walkNode(ast, state, 0, false);

  return {
    plainText: state.text,
    formattingRanges: state.formattingRanges,
    blockRanges: state.blockRanges,
  };
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
  const isListContainer =
    node.type === 'UnorderedList' || node.type === 'OrderedList';
  const childListDepth = isListContainer ? listDepth + 1 : listDepth;
  const childOrdered = isListContainer
    ? node.type === 'OrderedList'
    : orderedContainer;

  // Each list item starts on its own line; md4c emits no separator between
  // sibling items or before a nested sublist.
  if (
    node.type === 'ListItem' &&
    state.text.length > 0 &&
    !state.text.endsWith('\n')
  ) {
    state.text += '\n';
  }
  const itemStart = node.type === 'ListItem' ? state.text.length : -1;

  const parsedLevel = parseInt(node.attributes?.level ?? '', 10);
  const blockLevel = Number.isNaN(parsedLevel) ? 0 : parsedLevel;
  const blockType = nodeTypeToBlockType(node.type, blockLevel);
  const blockStartPosition = state.text.length;

  if (node.type === 'Text') {
    state.text += node.content ?? '';
  } else if (node.type === 'LineBreak' || node.type === 'SoftBreak') {
    state.text += '\n';
  }

  const children = node.children ?? [];
  for (let index = 0; index < children.length; index++) {
    const child = children[index]!;
    // Keep the source's blank lines between genuinely top-level blocks
    // (md4c drops them). Inside a list, items are separated by the single
    // newline inserted above, not blank lines.
    if (
      index > 0 &&
      listDepth === 0 &&
      TOP_LEVEL_BLOCK_TYPES.has(child.type) &&
      state.text.length > 0
    ) {
      state.text += '\n'.repeat(state.blankRuns.shift() ?? 2);
    }
    walkNode(child, state, childListDepth, childOrdered);
  }

  // A list item owns its own first line; a nested sublist lives on later
  // lines, so the item's range ends at the first newline after its start.
  if (itemStart >= 0) {
    let lineEnd = state.text.indexOf('\n', itemStart);
    if (lineEnd < 0) {
      lineEnd = state.text.length;
    }
    if (lineEnd > itemStart) {
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

export async function parseToPlainTextAndRanges(
  rawMarkdown: string
): Promise<ParseResult> {
  // U+200B is the editor's reserved empty-line anchor; strip it from incoming
  // markdown (web paste, JS-supplied values) before parsing so a foreign copy
  // can't seed a stray anchor and offsets stay consistent.
  const markdown = stripZwsp(rawMarkdown);
  if (markdown.length === 0) {
    return { plainText: '', formattingRanges: [], blockRanges: [] };
  }

  const completed = completeMarkdown(markdown);
  let ast: ASTNode;
  try {
    ast = await parseMarkdown(completed, INPUT_PARSE_FLAGS);
  } catch {
    // A failed parse degrades to unformatted text rather than crashing.
    return { plainText: markdown, formattingRanges: [], blockRanges: [] };
  }
  return parseResultFromAst(ast, completed);
}
