import {
  ANCHORED_BLOCK_TYPES,
  createBlockRange,
  LIST_ITEM_BLOCK_TYPES,
  MAX_LIST_DEPTH,
  type BlockRange,
  type BlockType,
} from '../model/blocks';
import { adjustRangesForEdit } from './RangeEditAdjustment';
import { sortedInsertionIndex } from './rangeStoreUtils';
import type { RangeBounds } from '../model/rangeBounds';

// Expands a selection to cover whole lines (line-scoped block boundaries).
export function paragraphBounds(
  rangeStart: number,
  rangeEnd: number,
  text: string
): RangeBounds {
  if (text.length === 0) {
    return { start: 0, end: 0 };
  }

  const clampedStart = Math.min(Math.max(rangeStart, 0), text.length);
  const clampedEnd = Math.min(Math.max(rangeEnd, clampedStart), text.length);

  let start = clampedStart;
  while (start > 0 && text[start - 1] !== '\n') {
    start--;
  }
  let end = clampedEnd;
  while (end < text.length && text[end] !== '\n') {
    end++;
  }
  return { start, end };
}

// Stores the block-level (line-scoped) ranges for the editor, mirroring
// FormattingStore. Block ranges never overlap: at most one block covers any
// paragraph, and ranges stay normalized to whole-line boundaries.
export class BlockStore {
  private ranges: BlockRange[] = [];

  get allRanges(): BlockRange[] {
    return [...this.ranges];
  }

  // Incoming ranges are trusted to be non-overlapping and line-scoped — the
  // parser owns that invariant.
  setRanges(newRanges: BlockRange[]): void {
    this.ranges = [...newRanges].sort((a, b) => a.start - b.start);
    this.recomputeListMetadata();
  }

  clearAll(): void {
    this.ranges = [];
  }

  // Sets/replaces the block on every paragraph the given range touches,
  // expanding to whole-line boundaries. Removes any block previously covering
  // those paragraphs.
  setBlock(
    type: BlockType,
    level: number,
    paragraphStart: number,
    paragraphEnd: number,
    text: string
  ): void {
    const { start, end } = paragraphBounds(paragraphStart, paragraphEnd, text);
    this.removeBlocksOverlapping(start, end);
    // An anchored block (heading, list item) on an empty line is kept as a
    // zero-length anchor; other blocks need real content.
    if (end < start || (end === start && !ANCHORED_BLOCK_TYPES.has(type))) {
      return;
    }
    const block = createBlockRange(type, start, end, level);
    this.ranges.splice(sortedInsertionIndex(this.ranges, start), 0, block);
  }

  // Clears any block on the paragraphs the given range touches, reverting
  // them to the implicit paragraph default.
  removeBlock(
    paragraphStart: number,
    paragraphEnd: number,
    text: string
  ): void {
    const { start, end } = paragraphBounds(paragraphStart, paragraphEnd, text);
    this.removeBlocksOverlapping(start, end);
  }

  // Snaps every stored range to the line bounds of its start position.
  // Absorbs edge-typed chars, clips split ranges to their first line, drops
  // duplicates. On an empty line an anchored block persists as a zero-length
  // anchor; any other collapsed range is dropped. Call after adjustForEdit
  // once `text` is final. Idempotent.
  normalizeToLineBounds(text: string): void {
    if (this.ranges.length === 0) {
      return;
    }

    let previousEnd = -1;
    this.ranges = this.ranges.filter((range) => {
      const line = paragraphBounds(range.start, range.start, text);
      const isEmptyLine = line.end === line.start;
      if (
        (isEmptyLine && !ANCHORED_BLOCK_TYPES.has(range.type)) ||
        line.start <= previousEnd
      ) {
        // Dedup: drop a range that resolves to an already-claimed paragraph.
        // This is a legitimate self-heal path (a heading anchor and the block
        // it merges into can briefly share a start after a line-join), so it
        // is deliberately silent.
        return false;
      }
      range.start = line.start;
      range.end = line.end;
      previousEnd = line.end;
      return true;
    });

    this.recomputeListMetadata();
  }

  // Clamps list depths to valid ancestry (an item nests at most one level
  // under the previous adjacent list item — CommonMark cannot represent
  // orphan nesting) and renumbers ordered items among their adjacent
  // same-depth, same-type run.
  private recomputeListMetadata(): void {
    let prevEnd = -2;
    let prevDepth = -1;
    const counters = new Array<number>(MAX_LIST_DEPTH + 2).fill(0);
    const counterTypes = new Array<BlockType | null>(MAX_LIST_DEPTH + 2).fill(
      null
    );

    for (const range of this.ranges) {
      if (!LIST_ITEM_BLOCK_TYPES.has(range.type)) {
        prevDepth = -1;
        continue;
      }
      const adjacent = prevDepth >= 0 && range.start === prevEnd + 1;
      if (!adjacent) {
        counters.fill(0);
        counterTypes.fill(null);
      }
      // Coerce into [0, MAX_LIST_DEPTH] before ancestry-clamping: this pass
      // indexes the counter arrays by depth, so an out-of-bounds level must
      // never survive it.
      const maxDepth = Math.min(adjacent ? prevDepth + 1 : 0, MAX_LIST_DEPTH);
      if (range.level > maxDepth) {
        range.level = maxDepth;
      } else if (range.level < 0) {
        range.level = 0;
      }
      const depth = range.level;
      for (let i = depth + 1; i <= MAX_LIST_DEPTH + 1; i++) {
        counters[i] = 0;
        counterTypes[i] = null;
      }
      if (counterTypes[depth] !== range.type) {
        counters[depth] = 0;
        counterTypes[depth] = range.type;
      }
      counters[depth] = counters[depth]! + 1;
      range.ordinal = counters[depth]!;
      prevEnd = range.end;
      prevDepth = range.level;
    }
  }

  // Blocks never partially overlap, so a touched block is removed wholesale; a
  // zero-length anchor is dropped when it sits within the bounds (so
  // toggle-off clears an empty line).
  private removeBlocksOverlapping(start: number, end: number): void {
    this.ranges = this.ranges.filter(
      (block) =>
        !(
          (block.end > start && block.start < end) ||
          (block.end === block.start &&
            block.start >= start &&
            block.start <= end)
        )
    );
  }

  // Shifts/clips block ranges to follow a text edit, with anchored-block
  // persistence layered on top: a block deleted exactly to its end collapses
  // to a zero-length anchor at the edit location (its line survives), and
  // existing anchors shift/keep/drop with their line.
  adjustForEdit(
    editLocation: number,
    deletedLength: number,
    insertedLength: number
  ): void {
    if (deletedLength === 0 && insertedLength === 0) {
      return;
    }

    const deleteEnd = editLocation + deletedLength;
    const delta = insertedLength - deletedLength;

    const anchors = this.ranges.filter(
      (b) => b.end === b.start && ANCHORED_BLOCK_TYPES.has(b.type)
    );
    let ranges = this.ranges.filter((b) => b.end !== b.start);

    // At most one range can end exactly at deleteEnd (blocks never overlap),
    // so this restores at most one collapsed block.
    const collapsed =
      ranges.find(
        (b) =>
          ANCHORED_BLOCK_TYPES.has(b.type) &&
          b.start >= editLocation &&
          b.end === deleteEnd
      ) ?? null;

    ranges = adjustRangesForEdit(
      ranges,
      editLocation,
      deletedLength,
      insertedLength,
      () => true,
      () => true
    );

    for (const anchor of anchors) {
      if (anchor.start <= editLocation) {
        // Keeps its position.
      } else if (anchor.start >= deleteEnd) {
        anchor.start += delta;
        anchor.end = anchor.start;
      } else {
        continue; // The anchor's line was deleted.
      }
      ranges.splice(sortedInsertionIndex(ranges, anchor.start), 0, anchor);
    }

    if (collapsed !== null && !ranges.includes(collapsed)) {
      const anchor = createBlockRange(
        collapsed.type,
        editLocation,
        editLocation,
        collapsed.level
      );
      ranges.splice(sortedInsertionIndex(ranges, editLocation), 0, anchor);
    }

    this.ranges = ranges;
  }

  // Starts are unique (one block per paragraph), so a binary search finds the
  // block whose paragraph starts exactly at `lineStart`.
  blockStartingAt(lineStart: number): BlockRange | null {
    let lo = 0;
    let hi = this.ranges.length - 1;
    while (lo <= hi) {
      const mid = Math.floor((lo + hi) / 2);
      const start = this.ranges[mid]!.start;
      if (start < lineStart) {
        lo = mid + 1;
      } else if (start > lineStart) {
        hi = mid - 1;
      } else {
        return this.ranges[mid]!;
      }
    }
    return null;
  }
}
