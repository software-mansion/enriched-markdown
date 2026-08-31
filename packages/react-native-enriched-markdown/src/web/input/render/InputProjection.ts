import type { BlockRange, BlockType } from '../model/blocks';
import type { FormattingRange, InputStyleType } from '../model/inlineStyles';
import type { RangeBounds } from '../model/rangeBounds';
import { clamp } from '../utils';

// Canonical order for a run's style list, so equal style sets compare equal.
const STYLE_ORDER: readonly InputStyleType[] = [
  'strong',
  'em',
  'underline',
  'strikethrough',
  'link',
  'spoiler',
];

// A maximal segment of text with one constant style set; renders as one
// DOM element.
export interface StyleRun extends RangeBounds {
  styles: InputStyleType[];
  url?: string;
}

function sameRunStyle(run: StyleRun, styles: InputStyleType[], url?: string) {
  return (
    run.url === url &&
    run.styles.length === styles.length &&
    run.styles.every((style, i) => style === styles[i])
  );
}

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
  // Closings before openings at the same position.
  if (a.isOpening !== b.isOpening) {
    return a.isOpening ? 1 : -1;
  }
  return 0;
}

// Flattens overlapping formatting ranges over [start, end) into disjoint
// runs — DOM elements cannot partially overlap.
export function computeStyleRuns(
  ranges: readonly FormattingRange[],
  start: number,
  end: number
): StyleRun[] {
  if (end <= start) return [];

  const events: BoundaryEvent[] = [];
  for (const range of ranges) {
    const rangeStart = clamp(range.start, start, end);
    const rangeEnd = clamp(range.end, start, end);
    if (rangeStart >= rangeEnd) continue;

    events.push({
      position: rangeStart,
      isOpening: true,
      type: range.type,
      url: range.url,
    });
    events.push({
      position: rangeEnd,
      isOpening: false,
      type: range.type,
      url: range.url,
    });
  }
  if (events.length === 0) {
    return [{ start, end, styles: [] }];
  }

  events.sort(compareBoundaryEvents);

  // Counts, not booleans: overlapping ranges of one type stay active until
  // all close.
  const activeCounts = new Map<InputStyleType, number>();
  const activeLinkUrls: (string | undefined)[] = [];
  const runs: StyleRun[] = [];
  let segmentStart = start;

  const emitRunUpTo = (segmentEnd: number) => {
    if (segmentEnd <= segmentStart) return;

    const styles = STYLE_ORDER.filter(
      (style) => (activeCounts.get(style) ?? 0) > 0
    );
    const url = activeLinkUrls[0];

    const previous = runs[runs.length - 1];
    if (previous && sameRunStyle(previous, styles, url)) {
      previous.end = segmentEnd;
    } else {
      runs.push(
        url === undefined
          ? { start: segmentStart, end: segmentEnd, styles }
          : { start: segmentStart, end: segmentEnd, styles, url }
      );
    }
    segmentStart = segmentEnd;
  };

  for (const event of events) {
    // Emit before applying: the current state styles the text up to here.
    emitRunUpTo(event.position);

    const count = activeCounts.get(event.type) ?? 0;
    activeCounts.set(event.type, count + (event.isOpening ? 1 : -1));
    if (event.type === 'link') {
      if (event.isOpening) {
        activeLinkUrls.push(event.url);
      } else {
        activeLinkUrls.splice(activeLinkUrls.indexOf(event.url), 1);
      }
    }
  }
  emitRunUpTo(end);

  return runs;
}

// One buffer line with its block metadata and style runs.
export interface ParagraphProjection extends RangeBounds {
  blockType: BlockType;
  level: number;
  ordinal: number;
  runs: StyleRun[];
}

// An emptied heading or list item keeps its block as a zero-length range
// pinned to the line start.
function isEmptyAnchor(block: BlockRange): boolean {
  return block.start === block.end;
}

function blockEndsBeforeLine(block: BlockRange, lineStart: number): boolean {
  return isEmptyAnchor(block)
    ? block.start < lineStart
    : block.end <= lineStart;
}

function blockCoversLine(
  block: BlockRange,
  lineStart: number,
  lineEnd: number
): boolean {
  return isEmptyAnchor(block)
    ? block.start === lineStart
    : lineEnd >= block.start && lineStart < block.end;
}

// Splits the buffer into per-line paragraphs. Expects block ranges sorted
// and line-normalized, as the store keeps them.
export function projectParagraphs(
  text: string,
  formattingRanges: readonly FormattingRange[],
  blockRanges: readonly BlockRange[]
): ParagraphProjection[] {
  const paragraphs: ParagraphProjection[] = [];
  let blockIndex = 0;
  let lineStart = 0;
  for (const line of text.split('\n')) {
    const lineEnd = lineStart + line.length;

    // Both advance left to right, so one pointer suffices.
    while (
      blockIndex < blockRanges.length &&
      blockEndsBeforeLine(blockRanges[blockIndex]!, lineStart)
    ) {
      blockIndex++;
    }

    const candidate = blockRanges[blockIndex];
    const block =
      candidate && blockCoversLine(candidate, lineStart, lineEnd)
        ? candidate
        : undefined;

    paragraphs.push({
      start: lineStart,
      end: lineEnd,
      blockType: block?.type ?? 'paragraph',
      level: block?.level ?? 0,
      ordinal: block?.ordinal ?? 1,
      runs: computeStyleRuns(formattingRanges, lineStart, lineEnd),
    });
    lineStart = lineEnd + 1;
  }
  return paragraphs;
}
