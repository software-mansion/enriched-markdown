import { adjustRangesForEdit } from './RangeEditAdjustment';
import { classify, type Neighbor } from './characterClass';
import { sortedInsertionIndex } from './rangeStoreUtils';
import type { FormattingRange, InputStyleType } from '../model/inlineStyles';
import type { RangeBounds } from '../model/rangeBounds';
import { isLowSurrogate } from '../utils';

// Invariants: ranges sorted by `start`; same-type ranges never overlap or
// touch, except links with different urls, which may touch (adjacent
// `[a](x)[b](y)` must stay separate). Edit paths keep them so, and imports
// arrive normalized (`normalizeFormattingRanges`); `setRanges` only sorts.
export class FormattingStore {
  private ranges: FormattingRange[] = [];
  private revision = 0;

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
  // "**a**\n\n**b**" is bold. A span of only line breaks reports inactive.
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

  // Active means the WHOLE selection is covered; a partially covered
  // selection gets the style applied everywhere. A caret only reports state;
  // pending styles mutate later. Returns whether the style was active.
  // `text` keeps line breaks out of the coverage check, so the toggle agrees
  // with the state a toolbar shows.
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

  // The range toggling `type` over [start, end) should cover, or null when
  // it is [start, end) itself. md4c ignores a "_" between two word characters
  // ("Intra-word underscore doesn't have special meaning"), so an underline
  // starting or ending inside a word would be written as markdown that reads
  // back with a literal "_" (and the serializer would drop it). Instead the
  // toggle, on or off, grows to the word's edges:
  // - a caret touching a word takes the whole word (at the word's edge the
  //   toggle only pends; `growToWholeWords` makes letters typed there join
  //   the word);
  // - a selection edge inside a word moves out to the word's edge.
  // A caret with no word on either side stays a caret. Another style's
  // delimiter can stop the growth inside a word (see `underlineSeparators`).
  wholeWordRange(
    type: InputStyleType,
    text: string,
    start: number,
    end: number
  ): RangeBounds | null {
    if (type !== 'underline') {
      return null;
    }
    if (
      start === end &&
      neighborBefore(text, start) !== 'word' &&
      neighborAt(text, start) !== 'word'
    ) {
      return null;
    }
    return this.grownToWords(
      text,
      start,
      end,
      start === end,
      this.underlineSeparators()
    );
  }

  // `grows` makes both edges grow, as a caret does; otherwise an edge next to
  // whitespace inside the range stays put.
  private grownToWords(
    text: string,
    start: number,
    end: number,
    grows: boolean,
    separators: UnderlineSeparators
  ): RangeBounds | null {
    // The end first: whether a delimiter at it is written outside the "_"
    // depends on the start, and the start's walk stops at any delimiter the
    // end's walk could have passed.
    let newEnd = end;
    if (grows || neighborBefore(text, end) !== 'whitespace') {
      while (
        neighborAt(text, newEnd) === 'word' &&
        !separators.end(newEnd, start)
      ) {
        newEnd += text.codePointAt(newEnd)! > 0xffff ? 2 : 1;
      }
    }
    let newStart = start;
    if (grows || neighborAt(text, start) !== 'whitespace') {
      while (
        neighborBefore(text, newStart) === 'word' &&
        !separators.start(newStart, newEnd)
      ) {
        newStart = codePointStartBefore(text, newStart);
      }
    }
    return newStart !== start || newEnd !== end
      ? { start: newStart, end: newEnd }
      : null;
  }

  // Whether the store gives `type` to text typed at a caret at `position`: a
  // range covers it or, for underline, an underlined word ends there, since
  // `growToWholeWords` pulls letters typed right after the word into it -
  // unless a delimiter written after the word's "_" stays between them. A
  // style starting there doesn't: typing at its start moves it along.
  isStyleActiveAtCaret(
    type: InputStyleType,
    position: number,
    text: string
  ): boolean {
    if (this.isStyleActive(type, position)) {
      return true;
    }
    if (
      type !== 'underline' ||
      position > text.length ||
      neighborBefore(text, position) !== 'word'
    ) {
      return false;
    }
    const word = this.ranges.find(
      (range) => range.type === 'underline' && range.end === position
    );
    return (
      word !== undefined &&
      !this.underlineSeparators().closesOutside(position, word.start)
    );
  }

  // Where another style's delimiter, written between an underline's "_" and
  // the letter beside it, already makes the "_" readable, so the underline
  // needs no growth there (every delimiter character is punctuation to md4c).
  // Growth follows one rule: it never changes an underline whose markdown
  // reads back, along with the styles beside it, and fixes one that doesn't.
  // So it follows where `MarkdownSerializer` writes delimiters:
  // - At one position closings come before openings, so a style ending where
  //   an underline starts, or starting where one ends, separates them:
  //   "*foo*_bar_", "_foo_**bar**".
  // - A style starting (or ending) along with the underline separates only
  //   when it nests outside it, and only a link or spoiler does: a "*", "**"
  //   or "~~" between a letter and "_" is one md4c wouldn't read, so the
  //   serializer would drop it and then the underline, which takes the whole
  //   word instead. The longer range nests outside, and of two over the same
  //   text, the link or spoiler: "foo[_bar_](u)". (The natives nest links
  //   inside, so there none does.)
  // The ranges are collected once per call, and no underline is among them,
  // so they stay valid while the underlines grow. A style md4c can't read at
  // its other edge, as a strikethrough starting inside a word, is dropped by
  // the serializer and so stops separating; that is not checked.
  private underlineSeparators(): UnderlineSeparators {
    const starts = new Set<number>();
    const ends = new Set<number>();
    // Per position, the furthest end of a link or spoiler starting there and
    // the earliest start of one ending there.
    const outerEnds = new Map<number, number>();
    const outerStarts = new Map<number, number>();
    for (const range of this.ranges) {
      if (range.type === 'underline' || range.start >= range.end) {
        continue;
      }
      starts.add(range.start);
      ends.add(range.end);
      if (range.type === 'link' || range.type === 'spoiler') {
        outerEnds.set(
          range.start,
          Math.max(range.end, outerEnds.get(range.start) ?? range.end)
        );
        outerStarts.set(
          range.end,
          Math.min(range.start, outerStarts.get(range.end) ?? range.start)
        );
      }
    }
    const closesOutside = (position: number, underlineStart: number) =>
      (outerStarts.get(position) ?? Infinity) <= underlineStart;
    return {
      start: (position, underlineEnd) =>
        ends.has(position) ||
        (outerEnds.get(position) ?? -Infinity) >= underlineEnd,
      end: (position, underlineStart) =>
        starts.has(position) || closesOutside(position, underlineStart),
      closesOutside,
    };
  }

  // Grows the underlines touching the edited span [editStart, editEnd) (in
  // the text after the edit; touching it at an edge counts) when the edit
  // left one starting or ending inside a word, to that word's edges, by the
  // selection rule of `wholeWordRange`: letters typed or pasted right before
  // or after an underlined word join it, and so does the word a deletion
  // glued to it. Underlines away from the edit are left as they are.
  growToWholeWords(text: string, editStart: number, editEnd: number): void {
    const touching = this.ranges.filter(
      (range) =>
        range.type === 'underline' &&
        range.start <= editEnd &&
        range.end >= editStart &&
        range.start < range.end &&
        range.end <= text.length
    );
    if (touching.length === 0) {
      return;
    }
    const separators = this.underlineSeparators();
    for (const range of touching) {
      const grown = this.grownToWords(
        text,
        range.start,
        range.end,
        false,
        separators
      );
      if (grown !== null) {
        this.addRange({ type: range.type, ...grown });
      }
    }
  }

  // Toggling OFF is never blocked.
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

  // Merges same-type (and same-url) ranges left adjacent or overlapping by an
  // edit: deleting the space in "**foo** **bar**" leaves two touching bold
  // ranges that would serialize as "**foo****bar**". `addRange` keeps this
  // invariant on insert; the edit path must too.
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

interface UnderlineSeparators {
  // An underline [position, underlineEnd) needs no growth before `position`.
  start(position: number, underlineEnd: number): boolean;
  // An underline [underlineStart, position) needs no growth after `position`.
  end(position: number, underlineStart: number): boolean;
  // The part of `end` a letter typed at `position` keeps: a link or spoiler
  // closing there outside the underline.
  closesOutside(position: number, underlineStart: number): boolean;
}

function neighborBefore(text: string, position: number): Neighbor {
  return position === 0
    ? 'whitespace'
    : classify(text.slice(codePointStartBefore(text, position), position));
}

function neighborAt(text: string, position: number): Neighbor {
  return position >= text.length
    ? 'whitespace'
    : classify(String.fromCodePoint(text.codePointAt(position)!));
}

function codePointStartBefore(text: string, position: number): number {
  return isLowSurrogate(text.charCodeAt(position - 1)) && position >= 2
    ? position - 2
    : position - 1;
}
