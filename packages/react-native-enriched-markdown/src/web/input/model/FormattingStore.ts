import { sortedInsertionIndex } from './rangeStoreUtils';
import type { FormattingRange, InputStyleType } from './types';

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

  removeRange(range: FormattingRange): void {
    const index = this.ranges.indexOf(range);
    if (index !== -1) {
      this.ranges.splice(index, 1);
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
