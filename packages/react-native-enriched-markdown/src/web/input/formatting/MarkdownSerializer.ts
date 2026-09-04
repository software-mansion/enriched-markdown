import { clamp, firstIndexReachingTarget, isWhitespace } from '../utils';
import { LIST_ITEM_BLOCK_TYPES, type BlockRange } from '../model/blocks';
import type { FormattingRange, InputStyleType } from '../model/inlineStyles';

// Zero-width space used by the editor to anchor an empty bullet line; it is an
// internal editing aid and must never appear in serialized markdown.
export const ZWSP = '\u200B';
// Single choke point for scrubbing the empty-line ZWSP anchor out of anything
// bound for JS. Route new output paths through this rather than scattering
// replace calls, so the anchor can never leak because one path forgot to strip.
export function stripZwsp(text: string): string {
  return text.replaceAll(ZWSP, '');
}

const OPENING_DELIMITERS: Record<InputStyleType, string> = {
  strong: '**',
  em: '*',
  underline: '_',
  strikethrough: '~~',
  link: '[',
  spoiler: '||',
};

function closingDelimiter(
  type: InputStyleType,
  url: string | undefined
): string {
  if (type === 'link') {
    return `](${url ?? ''})`;
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

interface BoundaryEvent {
  position: number;
  isOpening: boolean;
  type: InputStyleType;
  url: string | undefined;
}

function compareBoundaryEvents(a: BoundaryEvent, b: BoundaryEvent): number {
  if (a.position !== b.position) {
    return a.position - b.position;
  }
  // Closing events before opening events at the same position.
  if (a.isOpening !== b.isOpening) {
    return a.isOpening ? 1 : -1;
  }
  // Among openings: outer first (lower priority emitted first).
  // Among closings: inner first (higher priority emitted first) — LIFO order.
  return a.isOpening
    ? NESTING_PRIORITY[a.type] - NESTING_PRIORITY[b.type]
    : NESTING_PRIORITY[b.type] - NESTING_PRIORITY[a.type];
}

export function serializeInline(
  text: string,
  ranges: readonly FormattingRange[]
): string {
  if (ranges.length === 0) {
    return text;
  }

  const events: BoundaryEvent[] = [];
  for (const range of ranges) {
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

  events.sort(compareBoundaryEvents);

  const markdown: string[] = [];
  let lastPosition = 0;
  for (const event of events) {
    const position = Math.min(event.position, text.length);
    if (position > lastPosition) {
      markdown.push(text.slice(lastPosition, position));
      lastPosition = position;
    }
    markdown.push(
      event.isOpening
        ? OPENING_DELIMITERS[event.type]
        : closingDelimiter(event.type, event.url)
    );
  }
  if (lastPosition < text.length) {
    markdown.push(text.slice(lastPosition));
  }

  return markdown.join('');
}

// Block-aware serialization: serializes inline styles exactly as
// serializeInline, then prepends each line's block prefix.
// `blockPrefixProvider` is asked, per block range, for the markdown line
// marker (e.g. "# ", "- "); returning "" leaves the line unprefixed. Any ZWSP
// empty-line anchor is stripped so an empty bullet still serializes to a bare
// line rather than "- \u200B".
export function serialize(
  text: string,
  ranges: readonly FormattingRange[],
  blockRanges: readonly BlockRange[],
  blockPrefixProvider: (block: BlockRange) => string
): string {
  return stripZwsp(
    serializeWithAnchors(text, ranges, blockRanges, blockPrefixProvider)
  );
}

function serializeWithAnchors(
  text: string,
  ranges: readonly FormattingRange[],
  blockRanges: readonly BlockRange[],
  blockPrefixProvider: (block: BlockRange) => string
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
      `[MarkdownSerializer] Block serialization line-count invariant violated: plain=${plainLines.length} markdown=${markdownLines.length}`
    );
    return inlineMarkdown;
  }

  const lineStartOffsets: number[] = [];
  const lineEndOffsets: number[] = [];
  let runningOffset = 0;
  for (const line of plainLines) {
    lineStartOffsets.push(runningOffset);
    lineEndOffsets.push(runningOffset + line.length);
    runningOffset += line.length + 1; // +1 for the '\n' separator
  }

  for (const block of blockRanges) {
    const prefix = blockPrefixProvider(block);
    if (prefix === '') {
      continue;
    }

    const isZeroLength = block.end === block.start;
    const isListItem = LIST_ITEM_BLOCK_TYPES.has(block.type);
    for (
      let lineIndex = firstIndexReachingTarget(
        block.start,
        lineEndOffsets.length,
        (index) => lineEndOffsets[index]!
      );
      lineIndex < plainLines.length;
      lineIndex++
    ) {
      const lineStart = lineStartOffsets[lineIndex]!;
      const overlaps = isZeroLength
        ? lineStart === block.start
        : lineStart < block.end;
      if (!overlaps) {
        break;
      }
      // A marker-only list line ("- " with no content) re-parses as a setext
      // underline for the previous line; emit an empty list line bare. An
      // empty "# " heading is valid ATX and keeps its prefix.
      if (isListItem && stripZwsp(plainLines[lineIndex]!) === '') {
        continue;
      }
      markdownLines[lineIndex] = prefix + markdownLines[lineIndex]!;
    }
  }

  return markdownLines.join('\n');
}

// Default per-line markdown marker for a block, gathered from the native
// block handlers. The three-space list indent is wide enough for ordered
// markers; paragraphs carry no marker.
export function markdownLinePrefix(block: BlockRange): string {
  switch (block.type) {
    case 'paragraph':
      return '';
    case 'unordered-list-item':
      return '   '.repeat(Math.max(block.level, 0)) + '- ';
    case 'ordered-list-item':
      return '   '.repeat(Math.max(block.level, 0)) + `${block.ordinal}. `;
    default:
      return '#'.repeat(clamp(block.level, 1, 6)) + ' ';
  }
}
