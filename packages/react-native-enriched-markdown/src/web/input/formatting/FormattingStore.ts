import { adjustRangesForEdit } from './RangeEditAdjustment';
import { sortedInsertionIndex } from './rangeStoreUtils';
import type { FormattingRange, InputStyleType } from '../model/inlineStyles';
import type { RangeBounds } from '../model/rangeBounds';

// Invariants: ranges sorted by `start`; same-type ranges never overlap or
// touch, except links with different urls, which may touch (adjacent
// `[a](x)[b](y)` must stay separate). Edit paths keep them so, and imports
// arrive normalized (`normalizeFormattingRanges`); `setRanges` only sorts.
export class FormattingStore {
  private ranges: FormattingRange[] = [];
  private revision = 0;

  // Changes on every write, so a reader can tell the ranges moved on since it
  // last looked without comparing them.
  get version(): number {
    return this.revision;
  }

  // A live view, as on Android: read it right away and don't keep it across a
  // write - some writes change the array in place, others swap it.
  get allRanges(): readonly FormattingRange[] {
    return this.ranges;
  }

  setRanges(ranges: FormattingRange[]): void {
    this.ranges = [...ranges].sort((a, b) => a.start - b.start);
    this.revision++;
  }

  clearAll(): void {
    this.ranges = [];
    this.revision++;
  }

  rangesOfType(type: InputStyleType): FormattingRange[] {
    return this.ranges.filter((range) => range.type === type);
  }

  // Sorted by start, so no range past `position` can cover it.
  rangeOfType(type: InputStyleType, position: number): FormattingRange | null {
    for (const range of this.ranges) {
      if (range.start > position) {
        break;
      }
      if (range.type === type && position < range.end) {
        return range;
      }
    }
    return null;
  }

  isStyleActive(type: InputStyleType, position: number): boolean {
    return this.rangeOfType(type, position) !== null;
  }

  isStyleActiveInRange(
    type: InputStyleType,
    start: number,
    end: number
  ): boolean {
    for (const range of this.ranges) {
      if (range.start >= end) {
        break;
      }
      if (range.type === type && range.end > start) {
        return true;
      }
    }
    return false;
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
  // Given the text, line breaks need no coverage: no style shows on one, and
  // the serializer splits every range at them, so a select-all over
  // "**a**\n\n**b**" is bold. A span holding only line breaks then has
  // nothing to be styled, and reports inactive.
  isStyleFullyActive(
    type: InputStyleType,
    start: number,
    end: number,
    text?: string
  ): boolean {
    let position = start;
    let covered = text === undefined || start === end;
    while (position < end) {
      if (text !== undefined && text.charCodeAt(position) === 10) {
        position++;
        continue;
      }
      const match = this.rangeOfType(type, position);
      if (match === null) {
        return false;
      }
      covered = true;
      position = match.end;
    }
    return covered;
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

    this.revision++;
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

    this.revision++;
    // Remainders are fragments of a just-removed range and cannot overlap others.
    for (const remainder of remainders) {
      this.insertSorted(remainder);
    }
  }

  // Toggles `type` on [start, end). Active means the WHOLE selection is
  // covered; a partially covered selection gets the style applied everywhere.
  // A caret (start == end) only reports state — pending styles mutate later.
  // Returns whether the style was active.
  // `text`, when given, keeps line breaks out of the coverage check (see
  // `isStyleFullyActive`), so the toggle agrees with the state a toolbar shows.
  toggleStyle(
    type: InputStyleType,
    start: number,
    end: number,
    text?: string
  ): boolean {
    if (start < end) {
      const wasActive = this.isStyleFullyActive(type, start, end, text);
      if (wasActive) {
        this.removeType(type, start, end);
      } else {
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
  // cover it whole, and a caret strictly inside a link moves to its end -
  // unless it came from that end (`previousCaret`, the caret before the
  // move), which is ArrowLeft stepping back into the link: snapping it to the
  // end again would pin it there, so it carries on to the start.
  // Returns null when no adjustment is needed.
  selectionAdjustedForAtomicLinks(
    start: number,
    end: number,
    previousCaret: number | null = null
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
      const to = previousCaret === link.end ? link.start : link.end;
      return { start: to, end: to };
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
    this.revision++;
    this.coalesceAdjacentSameTypeRanges();
  }

  removeRange(range: FormattingRange): void {
    const index = this.ranges.indexOf(range);
    if (index !== -1) {
      this.ranges.splice(index, 1);
      this.revision++;
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
