import type { BlockRange, BlockType } from '../model/blocks';
import {
  INPUT_STYLE_TYPES,
  type FormattingRange,
  type InputStyleType,
} from '../model/inlineStyles';
import {
  compareBoundaryEvents,
  type BoundaryEvent,
} from '../model/boundaryEvents';
import { clamp, firstIndexReachingTarget } from '../utils';
import { isDev } from '../../../utils/isDev';

const LOG_PREFIX = '[EnrichedMarkdown - InputProjection]';

// A maximal segment of one line with one constant style set; renders as one
// DOM element. Offsets count from the line start, not the buffer start, so a
// line's runs stay valid however the text before it changes; slice them out
// of the line's own `text`.
export interface StyleRun {
  startInLine: number;
  endInLine: number;
  styles: InputStyleType[];
  url?: string;
}

// Element-wise comparison is valid because `INPUT_STYLE_TYPES` orders every
// run's styles canonically.
export function sameRunStyle(
  run: StyleRun,
  styles: InputStyleType[],
  url?: string
) {
  return (
    run.url === url &&
    run.styles.length === styles.length &&
    run.styles.every((style, i) => style === styles[i])
  );
}

// Disjoint runs, because DOM elements cannot partially overlap.
export function computeStyleRuns(
  ranges: readonly FormattingRange[],
  lineStart: number,
  lineEnd: number
): StyleRun[] {
  if (lineEnd <= lineStart) return [];

  const events: BoundaryEvent[] = [];
  for (const range of ranges) {
    const rangeStart = clamp(range.start, lineStart, lineEnd);
    const rangeEnd = clamp(range.end, lineStart, lineEnd);
    if (rangeStart >= rangeEnd) continue;

    events.push({
      position: rangeStart - lineStart,
      isOpening: true,
      type: range.type,
      url: range.url,
    });
    events.push({
      position: rangeEnd - lineStart,
      isOpening: false,
      type: range.type,
      url: range.url,
    });
  }
  const lineLength = lineEnd - lineStart;
  if (events.length === 0) {
    return [{ startInLine: 0, endInLine: lineLength, styles: [] }];
  }

  events.sort(compareBoundaryEvents);

  // Counts, not booleans: overlapping ranges of one type stay active until
  // all close.
  const activeCounts = new Map<InputStyleType, number>();
  const activeLinkUrls: (string | undefined)[] = [];
  const runs: StyleRun[] = [];
  let segmentStart = 0;

  const emitRunUpTo = (segmentEnd: number) => {
    if (segmentEnd <= segmentStart) return;

    const styles = INPUT_STYLE_TYPES.filter(
      (style) => (activeCounts.get(style) ?? 0) > 0
    );
    const url = activeLinkUrls[0];

    const previous = runs[runs.length - 1];
    if (previous && sameRunStyle(previous, styles, url)) {
      previous.endInLine = segmentEnd;
    } else {
      runs.push(
        url === undefined
          ? { startInLine: segmentStart, endInLine: segmentEnd, styles }
          : { startInLine: segmentStart, endInLine: segmentEnd, styles, url }
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
  emitRunUpTo(lineLength);

  return runs;
}

// Holds no buffer offsets, so a line the text around it shifts is still the
// same object. Never mutated once built: the projector and the renderer share
// these objects across renders.
export interface ParagraphProjection {
  readonly text: string;
  readonly blockType: BlockType;
  readonly level: number;
  readonly ordinal: number;
  readonly runs: readonly StyleRun[];
}

// Both arrays are fresh per projection and never mutated after it.
export interface Projection {
  readonly paragraphs: readonly ParagraphProjection[];
  readonly lineStarts: readonly number[];
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

// Expects block ranges sorted and line-normalized, as the store keeps them.
// The reference the incremental `ParagraphProjector` is checked against.
export function projectParagraphs(
  text: string,
  formattingRanges: readonly FormattingRange[],
  blockRanges: readonly BlockRange[]
): Projection {
  const paragraphs: ParagraphProjection[] = [];
  const lineStarts: number[] = [];
  let blockIndex = 0;
  let nextRange = 0;
  let activeRanges: FormattingRange[] = [];
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
    activeRanges = activeRanges.filter((range) => range.end > lineStart);
    while (
      nextRange < formattingRanges.length &&
      formattingRanges[nextRange]!.start < lineEnd
    ) {
      activeRanges.push(formattingRanges[nextRange]!);
      nextRange++;
    }

    const candidate = blockRanges[blockIndex];
    const block =
      candidate && blockCoversLine(candidate, lineStart, lineEnd)
        ? candidate
        : undefined;

    lineStarts.push(lineStart);
    paragraphs.push({
      text: line,
      blockType: block?.type ?? 'paragraph',
      level: block?.level ?? 0,
      ordinal: block?.ordinal ?? 1,
      runs: computeStyleRuns(activeRanges, lineStart, lineEnd),
    });
    lineStart = lineEnd + 1;
  }
  return { paragraphs, lineStarts };
}

// `version` changes on every write, which is how the projector notices a
// write nobody told it about.
export interface ProjectedFormatting {
  readonly allRanges: readonly FormattingRange[];
  readonly version: number;
}

// Only lines an edit or a style change touched are cut and styled again;
// every other line keeps its paragraph object. Text and style changes arrive
// as hints (`textEdited`, `stylesChanged`) right after the model changes, in
// order, so the line table always describes the current buffer. Block metadata is not hinted:
// every projection re-reads it for every line from the block store, since a
// block write anywhere can renumber a list below it.
//
// A missed hint costs speed, not correctness: a buffer or formatting version
// the hints do not account for falls back to a full projection (and is
// reported in development).
export class ParagraphProjector {
  private readonly formatting: ProjectedFormatting;
  // Parallel to `lineStarts`; null marks a line to cut and style again.
  private paragraphs: readonly (ParagraphProjection | null)[] = [];
  private lineStarts: readonly number[] = [];
  // The buffer and formatting version the line table describes; `text` null
  // means nothing is known and the next projection starts over.
  private text: string | null = null;
  private formattingVersion = -1;

  constructor(formatting: ProjectedFormatting) {
    this.formatting = formatting;
  }

  // For changes that replace the model wholesale (an import, undo/redo),
  // where a full pass is what it costs anyway.
  invalidate(): void {
    this.text = null;
  }

  // `text` with [editStart, editStart + deletedLength) of the previous
  // buffer replaced by `insertedText`. Call after the stores followed the
  // edit; their changes stay inside the edited lines.
  textEdited(
    editStart: number,
    deletedLength: number,
    insertedText: string,
    text: string
  ): void {
    if (this.text === null) {
      return;
    }
    const first = this.lineIndexAt(editStart);
    const last = this.lineIndexAt(editStart + deletedLength);
    const delta = insertedText.length - deletedLength;

    const starts: number[] = this.lineStarts.slice(0, first + 1);
    let newline = insertedText.indexOf('\n');
    while (newline !== -1) {
      starts.push(editStart + newline + 1);
      newline = insertedText.indexOf('\n', newline + 1);
    }
    const freshLines = starts.length - first;
    for (let i = last + 1; i < this.lineStarts.length; i++) {
      starts.push(this.lineStarts[i]! + delta);
    }

    this.paragraphs = this.paragraphs
      .slice(0, first)
      .concat(
        new Array<null>(freshLines).fill(null),
        this.paragraphs.slice(last + 1)
      );
    this.lineStarts = starts;
    this.text = text;
    this.formattingVersion = this.formatting.version;
  }

  stylesChanged(start: number, end: number): void {
    if (this.text === null) {
      return;
    }
    const first = this.lineIndexAt(start);
    const last = this.lineIndexAt(end);
    const paragraphs = this.paragraphs.slice();
    paragraphs.fill(null, first, last + 1);
    this.paragraphs = paragraphs;
    this.formattingVersion = this.formatting.version;
  }

  project(text: string, blockRanges: readonly BlockRange[]): Projection {
    if (
      this.text !== text ||
      this.formattingVersion !== this.formatting.version
    ) {
      if (isDev && this.text !== null) {
        console.error(
          `${LOG_PREFIX} the model changed without a projection hint; projecting every line`
        );
      }
      this.startOver(text);
    }

    const ranges = this.formatting.allRanges;
    const lineCount = this.lineStarts.length;
    const paragraphs = new Array<ParagraphProjection>(lineCount);
    let blockIndex = 0;
    let nextRange = 0;
    let activeRanges: FormattingRange[] = [];
    for (let i = 0; i < lineCount; i++) {
      const lineStart = this.lineStarts[i]!;
      const lineEnd =
        i + 1 < lineCount ? this.lineStarts[i + 1]! - 1 : text.length;

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
      const blockType = block?.type ?? 'paragraph';
      const level = block?.level ?? 0;
      const ordinal = block?.ordinal ?? 1;

      const kept = this.paragraphs[i];
      if (kept != null) {
        paragraphs[i] =
          kept.blockType === blockType &&
          kept.level === level &&
          kept.ordinal === ordinal
            ? kept
            : { ...kept, blockType, level, ordinal };
        continue;
      }

      // Ranges are sorted by start; a kept line skips its ranges here and
      // the next cut line drops the ones that ended before it.
      activeRanges = activeRanges.filter((range) => range.end > lineStart);
      while (nextRange < ranges.length && ranges[nextRange]!.start < lineEnd) {
        const range = ranges[nextRange]!;
        if (range.end > lineStart) {
          activeRanges.push(range);
        }
        nextRange++;
      }
      paragraphs[i] = {
        text: text.slice(lineStart, lineEnd),
        blockType,
        level,
        ordinal,
        runs: computeStyleRuns(activeRanges, lineStart, lineEnd),
      };
    }

    this.paragraphs = paragraphs;
    return { paragraphs, lineStarts: this.lineStarts };
  }

  private startOver(text: string): void {
    const starts = [0];
    let newline = text.indexOf('\n');
    while (newline !== -1) {
      starts.push(newline + 1);
      newline = text.indexOf('\n', newline + 1);
    }
    this.lineStarts = starts;
    this.paragraphs = new Array<null>(starts.length).fill(null);
    this.text = text;
    this.formattingVersion = this.formatting.version;
  }

  // The line holding `offset`; an offset on a newline belongs to the line
  // the newline ends.
  private lineIndexAt(offset: number): number {
    const starts = this.lineStarts;
    return (
      firstIndexReachingTarget(offset + 1, starts.length, (i) => starts[i]!) - 1
    );
  }
}
