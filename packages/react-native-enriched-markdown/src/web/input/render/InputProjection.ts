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
