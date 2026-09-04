import type { RangeBounds } from './rangeBounds';

// Block-level (line-scoped) element types. A block covers whole lines, unlike
// inline styles which cover character ranges. Every line is a paragraph until
// a block handler claims it.
export type BlockType =
  | 'paragraph'
  | 'h1'
  | 'h2'
  | 'h3'
  | 'h4'
  | 'h5'
  | 'h6'
  | 'unordered-list-item'
  | 'ordered-list-item';

export const HEADING_BLOCK_TYPES = [
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
] as const;

export const LIST_ITEM_BLOCK_TYPES: ReadonlySet<BlockType> = new Set([
  'unordered-list-item',
  'ordered-list-item',
]);

// Block types whose emptied line persists as a zero-length anchor (an emptied
// heading stays a heading, an emptied list item keeps its marker).
export const ANCHORED_BLOCK_TYPES: ReadonlySet<BlockType> = new Set([
  ...HEADING_BLOCK_TYPES,
  ...LIST_ITEM_BLOCK_TYPES,
]);

export function blockTypeForHeadingLevel(level: number): BlockType | null {
  return HEADING_BLOCK_TYPES[level - 1] ?? null;
}

// Maximum bullet-list nesting depth (0-based), so indent can't run away.
export const MAX_LIST_DEPTH = 5;

// A list line at depth d is indented (d + 1) * LIST_INDENT_PER_DEPTH px and
// its marker draws in the last slot (mirrors kENRMListIndentPerDepth).
export const LIST_INDENT_PER_DEPTH = 18;

// `level` is a generic payload: headings keep the H-level (1-6), list items
// their nesting depth. `ordinal` is the 1-based position of an ordered list
// item among adjacent siblings at the same depth, recomputed by the store.
export interface BlockRange extends RangeBounds {
  type: BlockType;
  level: number;
  ordinal: number;
}

export function createBlockRange(
  type: BlockType,
  start: number,
  end: number,
  level = 0
): BlockRange {
  return { type, start, end, level, ordinal: 1 };
}
