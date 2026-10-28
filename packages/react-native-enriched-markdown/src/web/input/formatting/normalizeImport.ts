import {
  HEADING_BLOCK_TYPES,
  LIST_ITEM_BLOCK_TYPES,
  type BlockRange,
  type BlockType,
} from '../model/blocks';
import type { FormattingRange } from '../model/inlineStyles';
import { firstIndexReachingTarget, lineEndOf, lineStartsOf } from '../utils';

// The parser reports what md4c saw, which the stores' invariants do not
// always admit: nested same-type spans ("**foo **bar** baz**"), a setext
// heading over two lines, a heading inside a list item ("- # foo"). Edits
// assume those invariants, so an import that breaks them goes wrong on the
// first keystroke rather than at load.

// Sorted by start, with same-type ranges that overlap or touch merged into
// one, as edit paths keep them. Links merge only when their urls match:
// adjacent `[a](x)[b](y)` stays two links.
export function normalizeFormattingRanges(
  ranges: readonly FormattingRange[]
): FormattingRange[] {
  const sorted = [...ranges].sort((a, b) => a.start - b.start);
  const merged: FormattingRange[] = [];
  // The last merged range of each type (and url, for links).
  const open = new Map<string, FormattingRange>();
  for (const range of sorted) {
    if (range.end <= range.start) {
      continue;
    }
    const key =
      range.type === 'link' ? `link\u0000${range.url ?? ''}` : range.type;
    const last = open.get(key);
    if (last !== undefined && range.start <= last.end) {
      last.end = Math.max(last.end, range.end);
      continue;
    }
    const copy = { ...range };
    merged.push(copy);
    open.set(key, copy);
  }
  return merged;
}

// When two blocks claim one line, the one kept. A list item is the outer
// structure ("- # foo" is an item holding a heading), and losing it would
// break the list's numbering and nesting around it; the line's text stays
// either way.
function blockPriority(type: BlockType): number {
  if (LIST_ITEM_BLOCK_TYPES.has(type)) {
    return 2;
  }
  return (HEADING_BLOCK_TYPES as readonly BlockType[]).includes(type) ? 1 : 0;
}

// One block per line, covering exactly that line, sorted by start: what the
// block store holds after every edit. A block spanning lines is copied onto
// each of them, which is how the editor shows it (a two-line setext heading
// renders as two heading lines) and how it will serialize.
export function normalizeBlockRanges(
  text: string,
  blocks: readonly BlockRange[]
): BlockRange[] {
  if (blocks.length === 0) {
    return [];
  }
  const lineStarts = lineStartsOf(text);
  const lineEnd = lineEndOf(text, lineStarts);

  // Indexed by line. Blocks arrive nearly sorted (a nested item is emitted
  // before its parent), so the line of each start is found walking from the
  // previous one, with a binary search only to go back.
  const byLine: Array<BlockRange | undefined> = [];
  let cursor = 0;
  const lineAt = (position: number) => {
    if (position < lineStarts[cursor]!) {
      cursor = firstIndexReachingTarget(position, lineStarts.length, lineEnd);
    }
    while (cursor + 1 < lineStarts.length && lineEnd(cursor) < position) {
      cursor++;
    }
    return cursor;
  };
  for (const block of blocks) {
    const first = lineAt(block.start);
    let last = first;
    while (last + 1 < lineStarts.length && lineEnd(last) < block.end - 1) {
      last++;
    }
    for (let line = first; line <= last; line++) {
      const kept = byLine[line];
      if (
        kept !== undefined &&
        blockPriority(kept.type) >= blockPriority(block.type)
      ) {
        continue;
      }
      byLine[line] = {
        ...block,
        start: lineStarts[line]!,
        end: lineEnd(line),
      };
    }
  }
  return byLine.filter((block) => block !== undefined);
}
