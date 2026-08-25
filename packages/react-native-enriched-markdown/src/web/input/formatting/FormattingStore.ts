import { adjustRangesForEdit } from './RangeEditAdjustment';
import { sortedInsertionIndex } from './rangeStoreUtils';
import type { FormattingRange, InputStyleType } from '../model/inlineStyles';
import type { RangeBounds } from '../model/rangeBounds';

// Invariants: ranges sorted by `start`; edit paths keep same-type ranges from
// overlapping or touching, except links with different urls, which may touch
// (adjacent `[a](x)[b](y)` must stay separate). `setRanges` only sorts, so
// imported ranges may touch — queries never assume coalesced input.
export class FormattingStore {
  private ranges: FormattingRange[] = [];

  get allRanges(): FormattingRange[] {
    return [...this.ranges];
  }

  setRanges(ranges: FormattingRange[]): void {
    this.ranges = [...ranges].sort((a, b) => a.start - b.start);
  }

  clearAll(): void {
    this.ranges = [];
  }

  rangesOfType(type: InputStyleType): FormattingRange[] {
    return this.ranges.filter((range) => range.type === type);
  }

  rangeOfType(type: InputStyleType, position: number): FormattingRange | null {
    return (
      this.ranges.find(
        (range) =>
          range.type === type && position >= range.start && position < range.end
      ) ?? null
    );
  }

  isStyleActive(type: InputStyleType, position: number): boolean {
    return this.rangeOfType(type, position) !== null;
  }

  isStyleActiveInRange(
    type: InputStyleType,
    start: number,
    end: number
  ): boolean {
    return this.ranges.some(
      (range) =>
        range.type === type &&
        Math.min(range.end, end) - Math.max(range.start, start) > 0
    );
  }

  isStyleAdjacentBefore(type: InputStyleType, position: number): boolean {
    if (position === 0) {
      return false;
    }
    return (
      this.rangeOfType(type, position) !== null ||
      this.rangeOfType(type, position - 1) !== null
    );
  }

  // Coverage may span several touching ranges; an empty range is fully active.
  isStyleFullyActive(
    type: InputStyleType,
    start: number,
    end: number
  ): boolean {
    let position = start;
    while (position < end) {
      const match = this.rangeOfType(type, position);
      if (match === null) {
        return false;
      }
      position = match.end;
    }
    return true;
  }

  // The merged range takes the new range's `url`.
  addRange(newRange: FormattingRange): void {
    let mergedStart = newRange.start;
    let mergedEnd = newRange.end;

    this.ranges = this.ranges.filter((existing) => {
      if (existing.type !== newRange.type) {
        return true;
      }
      if (existing.start <= mergedEnd && existing.end >= mergedStart) {
        mergedStart = Math.min(mergedStart, existing.start);
        mergedEnd = Math.max(mergedEnd, existing.end);
        return false;
      }
      return true;
    });

    this.insertSorted({
      type: newRange.type,
      start: mergedStart,
      end: mergedEnd,
      url: newRange.url,
    });
  }

  removeType(type: InputStyleType, start: number, end: number): void {
    const remainders: FormattingRange[] = [];

    this.ranges = this.ranges.filter((existing) => {
      if (existing.type !== type) {
        return true;
      }
      if (existing.end <= start || existing.start >= end) {
        return true;
      }
      if (existing.start < start) {
        remainders.push({
          type,
          start: existing.start,
          end: start,
          url: existing.url,
        });
      }
      if (existing.end > end) {
        remainders.push({
          type,
          start: end,
          end: existing.end,
          url: existing.url,
        });
      }
      return false;
    });

    // Remainders are fragments of a just-removed range and cannot overlap others.
    for (const remainder of remainders) {
      this.insertSorted(remainder);
    }
  }

  // Toggles `type` on [start, end). Active means the WHOLE selection is
  // covered; a partially covered selection gets the style applied everywhere.
  // A caret (start == end) only reports state — pending styles mutate later.
  // Returns whether the style was active.
  toggleStyle(
    type: InputStyleType,
    start: number,
    end: number,
    conflictingStyles: ReadonlySet<InputStyleType> = new Set()
  ): boolean {
    if (start < end) {
      const wasActive = this.isStyleFullyActive(type, start, end);
      if (wasActive) {
        this.removeType(type, start, end);
      } else {
        for (const conflict of conflictingStyles) {
          this.removeType(conflict, start, end);
        }
        this.addRange({ type, start, end });
      }
      return wasActive;
    }
    return this.isStyleActive(type, start);
  }

  // True when toggling `type` ON at `position` should be refused because a
  // blocking style is active there; toggling OFF is never blocked.
  isToggleBlocked(
    type: InputStyleType,
    position: number,
    blockingStyles: ReadonlySet<InputStyleType>
  ): boolean {
    if (blockingStyles.size === 0) {
      return false;
    }
    if (this.isStyleActive(type, position)) {
      return false;
    }
    for (const blocker of blockingStyles) {
      if (this.isStyleActive(blocker, position)) {
        return true;
      }
    }
    return false;
  }

  // Links are atomic: a selection partially overlapping a link expands to
  // cover it whole, and a caret strictly inside a link moves to its end.
  // Returns null when no adjustment is needed.
  selectionAdjustedForAtomicLinks(
    start: number,
    end: number
  ): RangeBounds | null {
    if (start !== end) {
      let newStart = start;
      let newEnd = end;
      const startLink = this.rangeOfType('link', newStart);
      if (startLink !== null) {
        newStart = Math.min(newStart, startLink.start);
      }
      if (newEnd > 0) {
        const endLink = this.rangeOfType('link', newEnd - 1);
        if (endLink !== null) {
          newEnd = Math.max(newEnd, endLink.end);
        }
      }
      if (newStart !== start || newEnd !== end) {
        return { start: newStart, end: newEnd };
      }
      return null;
    }
    const link = this.rangeOfType('link', start);
    if (link !== null && start > link.start && start < link.end) {
      return { start: link.end, end: link.end };
    }
    return null;
  }

  // Shifts/clips ranges to follow a text edit; styles inherit replacement
  // text (autocorrect keeps them), links never do.
  adjustForEdit(
    editLocation: number,
    deletedLength: number,
    insertedLength: number
  ): void {
    this.ranges = adjustRangesForEdit(
      this.ranges,
      editLocation,
      deletedLength,
      insertedLength,
      (range) => range.type !== 'link'
    );
    this.coalesceAdjacentSameTypeRanges();
  }

  removeRange(range: FormattingRange): void {
    const index = this.ranges.indexOf(range);
    if (index !== -1) {
      this.ranges.splice(index, 1);
    }
  }

  // Merge same-type (and same-url) ranges left adjacent or overlapping by an
  // edit — e.g. deleting the space in "**foo** **bar**" leaves two touching
  // bold ranges that would serialize as "**foo****bar**". `addRange` keeps
  // this invariant on insert; the edit path must too.
  private coalesceAdjacentSameTypeRanges(): void {
    let idx = 0;
    while (idx < this.ranges.length) {
      const current = this.ranges[idx]!;
      let next = idx + 1;
      while (
        next < this.ranges.length &&
        this.ranges[next]!.start <= current.end
      ) {
        const candidate = this.ranges[next]!;
        if (candidate.type === current.type && candidate.url === current.url) {
          current.end = Math.max(current.end, candidate.end);
          this.ranges.splice(next, 1);
        } else {
          next++;
        }
      }
      idx++;
    }
  }

  private insertSorted(range: FormattingRange): void {
    this.ranges.splice(
      sortedInsertionIndex(this.ranges, range.start),
      0,
      range
    );
  }
}
