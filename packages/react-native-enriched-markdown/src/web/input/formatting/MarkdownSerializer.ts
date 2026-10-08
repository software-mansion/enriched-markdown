import { clamp, firstIndexReachingTarget, isWhitespace } from '../utils';
import {
  HEADING_BLOCK_TYPES,
  LIST_ITEM_BLOCK_TYPES,
  MAX_LIST_DEPTH,
  type BlockRange,
} from '../model/blocks';
import type { FormattingRange, InputStyleType } from '../model/inlineStyles';
import {
  compareBoundaryEvents,
  type BoundaryEvent,
} from '../model/boundaryEvents';
import type { RangeBounds } from '../model/rangeBounds';

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

// Lower value = outermost wrapper. Font styles wrap around structural styles.
const NESTING_PRIORITY: Record<InputStyleType, number> = {
  em: 0,
  strong: 1,
  underline: 2,
  strikethrough: 3,
  spoiler: 4,
  link: 5,
};

// Among openings: outer first (lower priority emitted first).
// Among closings: inner first (higher priority emitted first) — LIFO order.
// Delimiters have to nest, unlike the projection's runs, which is why this
// sweep breaks ties where the shared comparator does not.
function compareNestingPriority(a: BoundaryEvent, b: BoundaryEvent): number {
  return a.isOpening
    ? NESTING_PRIORITY[a.type] - NESTING_PRIORITY[b.type]
    : NESTING_PRIORITY[b.type] - NESTING_PRIORITY[a.type];
}

// Every line is its own block (see BlockStore), and no inline run may cross a
// block boundary: "- **a\n- b**" re-parses as two items carrying literal
// asterisks rather than one bold run. Each range is therefore emitted once per
// line it covers, which also splits a link spanning lines into one link per
// line - the only form the block model can express.
function splitRangesAtLineBreaks(
  ranges: readonly FormattingRange[],
  text: string
): FormattingRange[] {
  const segments: FormattingRange[] = [];
  for (const range of ranges) {
    let start = range.start;
    while (start < range.end) {
      const lineBreak = text.indexOf('\n', start);
      const end =
        lineBreak === -1 || lineBreak >= range.end ? range.end : lineBreak;
      if (end > start) {
        segments.push({ ...range, start, end });
      }
      start = end + 1;
    }
  }
  return segments;
}

export function serializeInline(
  text: string,
  ranges: readonly FormattingRange[]
): string {
  if (ranges.length === 0) {
    return text;
  }

  const events: BoundaryEvent[] = [];
  for (const range of splitRangesAtLineBreaks(ranges, text)) {
    let start = clamp(range.start, 0, text.length);
    let end = clamp(range.end, 0, text.length);
    if (start >= end) {
      continue;
    }

    // Trim leading/trailing whitespace so delimiters hug non-whitespace content.
    while (start < end && isWhitespace(text.charAt(start))) {
      start++;
    }
    while (end > start && isWhitespace(text.charAt(end - 1))) {
      end--;
    }
    if (start >= end) {
      continue;
    }

    events.push({
      position: start,
      isOpening: true,
      type: range.type,
      url: range.url,
    });
    events.push({
      position: end,
      isOpening: false,
      type: range.type,
      url: range.url,
    });
  }

  events.sort((a, b) => compareBoundaryEvents(a, b, compareNestingPriority));

  let markdown = '';
  let lastPosition = 0;
  for (const event of events) {
    const position = Math.min(event.position, text.length);
    if (position > lastPosition) {
      markdown += text.slice(lastPosition, position);
      lastPosition = position;
    }
    markdown += event.isOpening
      ? OPENING_DELIMITERS[event.type]
      : closingDelimiter(event.type, event.url);
  }
  if (lastPosition < text.length) {
    markdown += text.slice(lastPosition);
  }

  return markdown;
}

// Block-aware serialization: serializes inline styles exactly as
// serializeInline, then prepends each line's markdownLinePrefix marker (e.g.
// "# ", "- "); a block whose marker is "" leaves its line unprefixed.
export function serialize(
  text: string,
  ranges: readonly FormattingRange[],
  blockRanges: readonly BlockRange[]
): string {
  const inlineMarkdown = serializeInline(text, ranges);
  if (blockRanges.length === 0) {
    return inlineMarkdown;
  }

  // Block prefixes attach per line. Inline serialization only inserts inline
  // delimiters (never newlines), so the serialized output has the same line
  // count as the plain text — we map a block's plain-text range to line
  // indices and prefix the corresponding serialized lines. If the invariant
  // ever breaks, prefixes would land on the wrong lines: log and fall back to
  // inline-only output — a library must not crash the host app over lost
  // block prefixes.
  const plainLines = text.split('\n');
  const markdownLines = inlineMarkdown.split('\n');
  if (plainLines.length !== markdownLines.length) {
    console.error(
      `[EnrichedMarkdown - MarkdownSerializer] Block serialization line-count invariant violated: plain=${plainLines.length} markdown=${markdownLines.length}`
    );
    return inlineMarkdown;
  }

  const lineBounds: RangeBounds[] = [];
  let runningOffset = 0;
  for (const line of plainLines) {
    lineBounds.push({ start: runningOffset, end: runningOffset + line.length });
    runningOffset += line.length + 1; // +1 for the '\n' separator
  }

  // Content column of the last list item seen at each depth, so a nested item
  // can indent to its parent's marker width. The store clamps a depth to one
  // more than the previous adjacent item's, so the parent's entry is always
  // already filled in by the time a child reads it.
  const listContentColumns: number[] = [];

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
    // the block's own first line; its remaining lines follow it.
    const firstLine = firstIndexReachingTarget(
      block.start,
      lineBounds.length,
      (index) => lineBounds[index]!.end
    );
    for (
      let lineIndex = firstLine;
      lineIndex < lineBounds.length;
      lineIndex++
    ) {
      const lineStart = lineBounds[lineIndex]!.start;
      const overlaps = isZeroLength
        ? lineStart === block.start
        : lineStart < block.end;
      if (!overlaps) {
        break;
      }
      // A marker-only list line ("- " with no content) re-parses as a setext
      // underline for the previous line; emit an empty list line bare. An
      // empty "# " heading is valid ATX and keeps its prefix.
      if (isListItem && plainLines[lineIndex] === '') {
        continue;
      }
      markdownLines[lineIndex] = prefix + markdownLines[lineIndex]!;
    }
  }

  return markdownLines.join('\n');
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
