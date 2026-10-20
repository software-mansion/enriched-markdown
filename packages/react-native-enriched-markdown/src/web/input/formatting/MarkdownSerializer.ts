import { clamp, firstIndexReachingTarget, isWhitespace } from '../utils';
import {
  HEADING_BLOCK_TYPES,
  LIST_ITEM_BLOCK_TYPES,
  MAX_LIST_DEPTH,
  type BlockRange,
} from '../model/blocks';
import type { FormattingRange, InputStyleType } from '../model/inlineStyles';
import type { BoundaryEvent } from '../model/boundaryEvents';
import { markdownEscapePositions } from './markdownEscape';

const OPENING_DELIMITERS: Record<InputStyleType, string> = {
  strong: '**',
  em: '*',
  underline: '_',
  strikethrough: '~~',
  link: '[',
  spoiler: '||',
};

function hasBalancedParens(url: string): boolean {
  let depth = 0;
  for (const char of url) {
    if (char === '(') {
      depth++;
    } else if (char === ')' && --depth < 0) {
      return false;
    }
  }
  return depth === 0;
}

// A bare destination ends at the first whitespace and at an unbalanced ")", so
// a url carrying either goes in angle brackets, where "<" and ">" need
// escaping as well. Backslash escapes are resolved in both forms, so a literal
// "\" has to be doubled before anything else is escaped - left bare, a url
// ending in one would escape the closing delimiter and swallow the rest of the
// line. No form admits a line ending at all, and one reaching the output would
// also break the line-count invariant `serialize` relies on, so line endings
// are percent-encoded rather than passed through.
function linkDestination(url: string): string {
  const escaped = url
    .replaceAll('\\', '\\\\')
    .replaceAll('\r', '%0D')
    .replaceAll('\n', '%0A');
  if (!/\s/.test(escaped) && hasBalancedParens(escaped)) {
    return escaped;
  }
  return `<${escaped.replaceAll('<', '\\<').replaceAll('>', '\\>')}>`;
}

function closingDelimiter(
  type: InputStyleType,
  url: string | undefined
): string {
  if (type === 'link') {
    return `](${linkDestination(url ?? '')})`;
  }
  return OPENING_DELIMITERS[type];
}

// Among styles covering exactly the same text, lower is outermost. A link or
// spoiler goes outside font styles: "[**docs**](u)s" parses, while
// "**[docs](u)**s" does not - a closing "**" after ")" and before a letter is
// not right-flanking.
const NESTING_PRIORITY: Record<InputStyleType, number> = {
  link: 0,
  spoiler: 1,
  em: 2,
  strong: 3,
  underline: 4,
  strikethrough: 5,
};

// The part of a range on one line, trimmed so its delimiters hug
// non-whitespace: an opening "**" before a space or a closing one after it is
// not flanking, and the parser would leave it as text.
interface Segment {
  type: InputStyleType;
  url: string | undefined;
  start: number;
  end: number;
}

// Of two delimiters opening at one position, the one written first is the
// outer one, so it has to be the one that closes last.
function opensOutside(a: Segment, b: Segment): number {
  return b.end - a.end || NESTING_PRIORITY[a.type] - NESTING_PRIORITY[b.type];
}

// Whitespace as `\s` matches it, without a regex call for the ASCII cases
// that make up nearly all text.
function isWhitespaceAt(text: string, index: number): boolean {
  const code = text.charCodeAt(index);
  if (code < 0x80) {
    return code === 0x20 || (code >= 0x09 && code <= 0x0d);
  }
  return isWhitespace(text.charAt(index));
}

function lineStartsOf(text: string): number[] {
  const lineStarts = [0];
  for (
    let lineBreak = text.indexOf('\n');
    lineBreak !== -1;
    lineBreak = text.indexOf('\n', lineBreak + 1)
  ) {
    lineStarts.push(lineBreak + 1);
  }
  return lineStarts;
}

// Every line is its own block (see BlockStore), and no inline run may cross a
// block boundary: "- **a\n- b**" re-parses as two items carrying literal
// asterisks rather than one bold run. Each range is therefore emitted once per
// line it covers, which also splits a link spanning lines into one link per
// line - the only form the block model can express. Sorted by start.
function lineSegments(
  text: string,
  ranges: readonly FormattingRange[],
  lineStarts: readonly number[]
): Segment[] {
  const lineEnd = (line: number) =>
    line + 1 < lineStarts.length ? lineStarts[line + 1]! - 1 : text.length;
  const segments: Segment[] = [];
  let sorted = true;
  // The line of the last range's start. Ranges come sorted by start (the
  // store keeps them so), so this walks forward through the lines once;
  // only a range starting behind it is looked up.
  let cursor = 0;
  for (const range of ranges) {
    const rangeEnd = clamp(range.end, 0, text.length);
    let start = clamp(range.start, 0, text.length);
    if (start >= rangeEnd) {
      continue;
    }
    if (start < lineStarts[cursor]!) {
      cursor = lineAt(lineStarts, start);
    }
    while (lineEnd(cursor) < start) {
      cursor++;
    }
    for (let line = cursor; start < rangeEnd; line++) {
      const end = Math.min(lineEnd(line), rangeEnd);
      let from = start;
      let to = end;
      while (from < to && isWhitespaceAt(text, from)) {
        from++;
      }
      while (to > from && isWhitespaceAt(text, to - 1)) {
        to--;
      }
      if (from < to) {
        const previous = segments[segments.length - 1];
        sorted &&= previous === undefined || previous.start <= from;
        segments.push({
          type: range.type,
          url: range.url,
          start: from,
          end: to,
        });
      }
      start = end + 1;
    }
  }
  if (!sorted) {
    // Only a range spanning lines puts a later line's segment ahead of the
    // next range's.
    segments.sort((a, b) => a.start - b.start);
  }
  return segments;
}

// The line holding `position`.
function lineAt(lineStarts: readonly number[], position: number): number {
  return firstIndexReachingTarget(position + 1, lineStarts.length, (i) =>
    i + 1 < lineStarts.length ? lineStarts[i + 1]! : Infinity
  );
}

export function serializeInline(
  text: string,
  ranges: readonly FormattingRange[]
): string {
  return writeMarkdown(
    text,
    ranges.length === 0 ? [] : inlineEvents(text, ranges, lineStartsOf(text))
  );
}

interface SegmentEvent extends BoundaryEvent {
  segment: Segment;
}

// The delimiters to write, in output order. Ranges may overlap any way they
// like, but delimiters have to nest, so this keeps a stack of open segments:
// where one ends, everything opened inside it closes too, and the ones that
// go on past it reopen right after - at the next non-whitespace character,
// since a delimiter before a space does not open. Where several open at once,
// the one closing last opens first.
//
// A segment whose delimiters md4c would not read as one - "**Note:**text",
// underline over half a word - is dropped, and the rest written again without
// it: losing a style beats writing its delimiters into the text, where every
// reload would keep them.
function inlineEvents(
  text: string,
  ranges: readonly FormattingRange[],
  lineStarts: readonly number[]
): BoundaryEvent[] {
  let segments = lineSegments(text, ranges, lineStarts);
  while (true) {
    const events = nestedEvents(text, segments);
    const unreadable = unflankedSegments(text, events);
    if (unreadable.size === 0) {
      return events;
    }
    segments = segments.filter((segment) => !unreadable.has(segment));
  }
}

function nestedEvents(
  text: string,
  segments: readonly Segment[]
): SegmentEvent[] {
  const events: SegmentEvent[] = [];
  const stack: Segment[] = [];
  const opening: Segment[] = [];
  let next = 0;
  while (next < segments.length || stack.length > 0) {
    let position =
      next < segments.length ? segments[next]!.start : Number.MAX_VALUE;
    let deepest = -1;
    for (let i = 0; i < stack.length; i++) {
      const end = stack[i]!.end;
      if (end < position) {
        position = end;
        deepest = i;
      } else if (end === position && deepest === -1) {
        deepest = i;
      }
    }

    if (deepest !== -1) {
      while (stack.length > deepest) {
        const segment = stack.pop()!;
        events.push({
          position,
          isOpening: false,
          type: segment.type,
          url: segment.url,
          segment,
        });
        if (segment.end > position) {
          opening.push(segment);
        }
      }
    }
    while (next < segments.length && segments[next]!.start === position) {
      opening.push(segments[next++]!);
    }
    if (opening.length === 0) {
      continue;
    }

    // A segment opening here starts on non-whitespace, so this only moves
    // reopened ones, and nothing ends or starts in the whitespace skipped.
    let openAt = position;
    while (isWhitespaceAt(text, openAt)) {
      openAt++;
    }
    opening.sort(opensOutside);
    for (const segment of opening) {
      stack.push(segment);
      events.push({
        position: openAt,
        isOpening: true,
        type: segment.type,
        url: segment.url,
        segment,
      });
    }
    opening.length = 0;
  }
  return events;
}

// What sits on one side of a delimiter in the output. A line's edge reads as
// whitespace (a block marker ends in a space), and another delimiter as
// punctuation, which every delimiter character is - except a "*" next to a
// "*", which joins its run (see `isStarDelimiter`).
type Neighbor = 'whitespace' | 'punctuation' | 'word';

const UNICODE_PUNCTUATION_RE = /[\p{P}\p{S}]/u;

// md4c's classes: CommonMark punctuation is Unicode P and S, so an emoji
// counts as punctuation next to "**".
function classify(char: string): Neighbor {
  const code = char.charCodeAt(0);
  if (code < 0x80) {
    if (code === 0x20 || (code >= 0x09 && code <= 0x0d)) {
      return 'whitespace';
    }
    const isAsciiPunctuation =
      (code >= 0x21 && code <= 0x2f) ||
      (code >= 0x3a && code <= 0x40) ||
      (code >= 0x5b && code <= 0x60) ||
      (code >= 0x7b && code <= 0x7e);
    return isAsciiPunctuation ? 'punctuation' : 'word';
  }
  if (isWhitespace(char)) {
    return 'whitespace';
  }
  return UNICODE_PUNCTUATION_RE.test(char) ? 'punctuation' : 'word';
}

// "*" and "**" written side by side are one delimiter run to md4c, and a
// run's flanking is decided by what is around the whole run, not by the "*"
// next to each part: "***a***b" is bold italic "a". Any other delimiter in
// between ends the run and is punctuation.
function isStarDelimiter(type: InputStyleType): boolean {
  return type === 'em' || type === 'strong';
}

function neighborBefore(
  text: string,
  events: readonly SegmentEvent[],
  index: number
): Neighbor {
  const position = events[index]!.position;
  const star = isStarDelimiter(events[index]!.type);
  for (let i = index - 1; i >= 0 && events[i]!.position === position; i--) {
    if (!star || !isStarDelimiter(events[i]!.type)) {
      return 'punctuation';
    }
  }
  if (position === 0 || text.charCodeAt(position - 1) === 0x0a) {
    return 'whitespace';
  }
  const code = text.charCodeAt(position - 1);
  // The whole code point, so an emoji is classified as one.
  const isLowSurrogate = code >= 0xdc00 && code <= 0xdfff && position >= 2;
  return classify(
    text.slice(isLowSurrogate ? position - 2 : position - 1, position)
  );
}

function neighborAfter(
  text: string,
  events: readonly SegmentEvent[],
  index: number
): Neighbor {
  const position = events[index]!.position;
  const star = isStarDelimiter(events[index]!.type);
  for (
    let i = index + 1;
    i < events.length && events[i]!.position === position;
    i++
  ) {
    if (!star || !isStarDelimiter(events[i]!.type)) {
      return 'punctuation';
    }
  }
  if (position === text.length || text.charCodeAt(position) === 0x0a) {
    return 'whitespace';
  }
  return classify(String.fromCodePoint(text.codePointAt(position)!));
}

// Whether md4c reads a delimiter between `before` and `after` as the opening
// (or the closing) it stands for. Measured against the parser rather than
// taken from the spec, because "_" (underline here) and "~~" are extensions:
// - "*" / "**": CommonMark flanking. An opener is left-flanking - not before
//   whitespace, and not before punctuation unless whitespace or punctuation
//   precedes it - and a closer the mirror image.
// - "_" / "~~": an opener must not follow a letter or digit, nor a closer
//   precede one: neither works inside a word.
// - "||" and links take any neighbors.
function isFlanking(
  type: InputStyleType,
  isOpening: boolean,
  before: Neighbor,
  after: Neighbor
): boolean {
  const [inner, outer] = isOpening ? [after, before] : [before, after];
  switch (type) {
    case 'em':
    case 'strong':
      return (
        inner !== 'whitespace' && (inner !== 'punctuation' || outer !== 'word')
      );
    case 'underline':
    case 'strikethrough':
      return inner !== 'whitespace' && outer !== 'word';
    case 'spoiler':
    case 'link':
      return true;
  }
}

function unflankedSegments(
  text: string,
  events: readonly SegmentEvent[]
): Set<Segment> {
  const unflanked = new Set<Segment>();
  for (let i = 0; i < events.length; i++) {
    const event = events[i]!;
    if (
      event.type !== 'link' &&
      event.type !== 'spoiler' &&
      !isFlanking(
        event.type,
        event.isOpening,
        neighborBefore(text, events, i),
        neighborAfter(text, events, i)
      )
    ) {
      unflanked.add(event.segment);
    }
  }
  return unflanked;
}

const EXCLAMATION = 0x21;

// A "!" written right before a link's "[" turns the link into an image, which
// re-imports as its bare text with the "!" and the url gone. Unlike the other
// escapes this depends on the delimiters, so it is decided here: the "!" ahead
// of a link opening is escaped unless another delimiter is written between
// them ("!**[a](u)**" is no image). Merged into `escapes`, which stays sorted.
function withImageMarkerEscapes(
  escapes: number[],
  text: string,
  events: readonly BoundaryEvent[]
): number[] {
  const markers: number[] = [];
  for (let i = 0; i < events.length; i++) {
    const event = events[i]!;
    const at = event.position - 1;
    if (
      event.isOpening &&
      event.type === 'link' &&
      at >= 0 &&
      text.charCodeAt(at) === EXCLAMATION &&
      (i === 0 || events[i - 1]!.position !== event.position)
    ) {
      markers.push(at);
    }
  }
  if (markers.length === 0) {
    return escapes;
  }
  const merged: number[] = [];
  let m = 0;
  for (const at of escapes) {
    for (; m < markers.length && markers[m]! < at; m++) {
      merged.push(markers[m]!);
    }
    merged.push(at);
  }
  for (; m < markers.length; m++) {
    merged.push(markers[m]!);
  }
  return merged;
}

// Copies `text` with the events' delimiters and the lines' block markers
// written in. `linePrefixes` is indexed like `lineStarts`, and a line with no
// entry gets no marker. A marker lands in front of its line's first character,
// and so in front of any delimiter opening there; no delimiter closes at a line
// start, because a range is split into one segment per line and each segment
// ends on its own line.
function writeMarkdown(
  text: string,
  events: readonly BoundaryEvent[],
  lineStarts: readonly number[] = [],
  linePrefixes: readonly (string | undefined)[] = []
): string {
  let markdown = '';
  let written = 0;
  let nextLine = 0;
  const escapes = withImageMarkerEscapes(
    markdownEscapePositions(text),
    text,
    events
  );
  let nextEscape = 0;
  const copyText = (end: number) => {
    for (
      ;
      nextEscape < escapes.length && escapes[nextEscape]! < end;
      nextEscape++
    ) {
      const at = escapes[nextEscape]!;
      markdown += text.slice(written, at) + '\\';
      written = at;
    }
    if (end > written) {
      markdown += text.slice(written, end);
      written = end;
    }
  };
  const copyTo = (position: number) => {
    for (
      ;
      nextLine < lineStarts.length && lineStarts[nextLine]! <= position;
      nextLine++
    ) {
      const prefix = linePrefixes[nextLine];
      if (prefix !== undefined) {
        copyText(lineStarts[nextLine]!);
        markdown += prefix;
      }
    }
    copyText(position);
  };

  for (const event of events) {
    copyTo(event.position);
    markdown += event.isOpening
      ? OPENING_DELIMITERS[event.type]
      : closingDelimiter(event.type, event.url);
  }
  copyTo(text.length);
  return markdown;
}

// Block-aware serialization: serializes inline styles exactly as
// serializeInline, with each line's markdownLinePrefix marker (e.g. "# ",
// "- ") in front of it; a block whose marker is "" leaves its line unprefixed.
// Markers are written during the same sweep as the delimiters, so the output is
// never split back into lines. That relies on delimiters never carrying a line
// ending, which is why link destinations percent-encode theirs.
export function serialize(
  text: string,
  ranges: readonly FormattingRange[],
  blockRanges: readonly BlockRange[]
): string {
  if (blockRanges.length === 0) {
    return serializeInline(text, ranges);
  }

  const lineStarts = lineStartsOf(text);
  const lineEnd = (line: number) =>
    line + 1 < lineStarts.length ? lineStarts[line + 1]! - 1 : text.length;
  const linePrefixes: (string | undefined)[] = [];
  // Per line: the depth of its list item, or Infinity for a heading; unset on
  // a paragraph line. Blocks come in line order, so the previous line's entry
  // is in place by the time a line reads it.
  const lineDepths: number[] = [];
  // md4c reads a marker-only line as an empty item unless the line right above
  // holds paragraph text it would continue: "a\n-" is a setext underline,
  // "a\n1." paragraph text, and "- a\n  -" an underline inside the item. An
  // empty line, a heading, or an item at least as deep ends that text first.
  const startsEmptyItem = (line: number, depth: number) =>
    line === 0 ||
    lineEnd(line - 1) === lineStarts[line - 1] ||
    (lineDepths[line - 1] ?? -1) >= depth;

  // Content column of the last list item seen at each depth, so a nested item
  // can indent to its parent's marker width. The store clamps a depth to one
  // more than the previous adjacent item's, so the parent's entry is always
  // already filled in by the time a child reads it.
  const listContentColumns: number[] = [];
  // First line of the last block given a marker. The store keeps blocks sorted
  // by start, so the next block's first line is found by walking on from here.
  let cursor = 0;

  for (const block of blockRanges) {
    const isListItem = LIST_ITEM_BLOCK_TYPES.has(block.type);
    const depth = isListItem ? clamp(block.level, 0, MAX_LIST_DEPTH) : 0;
    const prefix = markdownLinePrefix(
      block,
      depth === 0 ? 0 : listContentColumns[depth - 1]
    );
    if (isListItem) {
      listContentColumns[depth] = prefix.length;
    }
    if (prefix === '') {
      continue;
    }

    const isZeroLength = block.end === block.start;
    // Line ends rise strictly, so the first line reaching the block's start is
    // the block's own first line; its remaining lines follow it. A block
    // starting behind the cursor (callers other than the store need not sort)
    // is looked up instead.
    if (cursor > 0 && lineEnd(cursor - 1) >= block.start) {
      cursor = firstIndexReachingTarget(
        block.start,
        lineStarts.length,
        lineEnd
      );
    }
    while (cursor < lineStarts.length && lineEnd(cursor) < block.start) {
      cursor++;
    }
    for (let line = cursor; line < lineStarts.length; line++) {
      const lineStart = lineStarts[line]!;
      const overlaps = isZeroLength
        ? lineStart === block.start
        : lineStart < block.end;
      if (!overlaps) {
        break;
      }
      lineDepths[line] = isListItem ? depth : Infinity;
      // An empty item md4c would not read back as one is left bare. An empty
      // "# " heading is valid ATX and keeps its prefix.
      if (
        isListItem &&
        lineEnd(line) === lineStart &&
        !startsEmptyItem(line, depth)
      ) {
        continue;
      }
      linePrefixes[line] = prefix + (linePrefixes[line] ?? '');
    }
  }

  return writeMarkdown(
    text,
    ranges.length === 0 ? [] : inlineEvents(text, ranges, lineStarts),
    lineStarts,
    linePrefixes
  );
}

// Width of "- " or "1. ", the narrowest markers a list item can carry.
const SINGLE_DIGIT_MARKER_WIDTH = 3;

// A nested item has to be indented to its parent's content column or it
// de-nests on re-parse, and that column is the parent's rendered marker width:
// "1. " and "10. " do not indent their children alike. `parentContentColumn`
// carries it down from `serialize`; callers with no document context fall back
// to assuming single-digit markers all the way up. Depth is clamped the way the
// block store clamps it, so a stray level cannot indent a line far enough to
// re-parse as a code block.
function listIndent(
  level: number,
  parentContentColumn: number | undefined
): string {
  const depth = clamp(level, 0, MAX_LIST_DEPTH);
  if (depth === 0) {
    return '';
  }
  return ' '.repeat(parentContentColumn ?? SINGLE_DIGIT_MARKER_WIDTH * depth);
}

// Per-line markdown marker for a block; paragraphs carry no marker. A
// heading's level comes from its type rather than from `level`, so the two
// cannot disagree. `parentContentColumn` is the content column of the list item
// this one nests under, ignored by every type that cannot nest. There is
// deliberately no `default` arm: a block type added to the model has to be
// given a marker here or this stops compiling.
export function markdownLinePrefix(
  block: BlockRange,
  parentContentColumn?: number
): string {
  switch (block.type) {
    case 'paragraph':
      return '';
    case 'unordered-list-item':
      return listIndent(block.level, parentContentColumn) + '- ';
    case 'ordered-list-item':
      return (
        listIndent(block.level, parentContentColumn) + `${block.ordinal}. `
      );
    case 'h1':
    case 'h2':
    case 'h3':
    case 'h4':
    case 'h5':
    case 'h6':
      return '#'.repeat(HEADING_BLOCK_TYPES.indexOf(block.type) + 1) + ' ';
  }
}
