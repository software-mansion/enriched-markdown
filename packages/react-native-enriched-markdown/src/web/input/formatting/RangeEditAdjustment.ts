import type { RangeBounds } from '../model/rangeBounds';

type EditOverlap =
  | 'before-edit'
  | 'after-edit'
  | 'fully-deleted'
  | 'deleted-inside'
  | 'clipped-end'
  | 'clipped-start';

function classifyOverlap(
  range: RangeBounds,
  deleted: RangeBounds
): EditOverlap {
  if (range.end <= deleted.start) return 'before-edit';
  if (range.start >= deleted.end) return 'after-edit';
  if (range.start >= deleted.start && range.end <= deleted.end) {
    return 'fully-deleted';
  }
  if (range.start < deleted.start && range.end > deleted.end) {
    return 'deleted-inside';
  }
  return range.start < deleted.start ? 'clipped-end' : 'clipped-start';
}

/**
 * Applies an edit that replaced the `deleted` span with `insertedLength`
 * characters to one range. A range the edit removes outright collapses to zero
 * length instead of being reported separately; the caller drops it when it
 * filters out empty ranges.
 *
 * `clipped-end` only classifies ranges starting before the deletion, so the
 * surviving head is never empty and the range always keeps its start.
 */
function applyReplacement<T extends RangeBounds>(
  range: T,
  deleted: RangeBounds,
  insertedLength: number,
  inheritsReplacementAtStart: (range: T) => boolean
): void {
  const delta = insertedLength - (deleted.end - deleted.start);
  const inheritsReplacement =
    insertedLength > 0 &&
    range.start === deleted.start &&
    inheritsReplacementAtStart(range);

  switch (classifyOverlap(range, deleted)) {
    case 'before-edit':
      break;

    case 'after-edit':
      range.start += delta;
      range.end += delta;
      break;

    case 'fully-deleted':
      if (inheritsReplacement) {
        range.start = deleted.start;
        range.end = deleted.start + insertedLength;
      } else {
        range.end = range.start;
      }
      break;

    case 'deleted-inside':
      range.end += delta;
      break;

    case 'clipped-end':
      range.end = deleted.start + insertedLength;
      break;

    case 'clipped-start': {
      const survivingLength = range.end - deleted.end;
      if (inheritsReplacement) {
        range.start = deleted.start;
        range.end = deleted.start + insertedLength + survivingLength;
      } else {
        range.start = deleted.start + insertedLength;
        range.end = range.start + survivingLength;
      }
      break;
    }
  }
}

function applyInsertion(
  range: RangeBounds,
  editLocation: number,
  insertedLength: number
): void {
  if (range.start >= editLocation) {
    range.start += insertedLength;
    range.end += insertedLength;
  } else if (editLocation < range.end) {
    range.end += insertedLength;
  }
}

/**
 * Shift/clip logic applied to stored ranges after a text edit that replaced
 * `deletedLength` characters at `editLocation` with `insertedLength`
 * characters. Bounds are mutated in place; the returned array drops ranges
 * deleted outright or clipped to zero length.
 *
 * Insert-only edits at exactly `range.end` do NOT grow the range - whether
 * typed text continues a style is decided by the pending-styles layer, and
 * links must never auto-extend. An insert at exactly `range.start` shifts the
 * range so the typed characters stay outside it (a character typed before a
 * bold run must not become bold).
 *
 * `inheritsReplacementAtStart`: when true for a range whose start is the edit
 * location, replacement text joins the range (autocorrect over a styled word
 * keeps the style); when false, the plain clip/remove behavior applies.
 */
export function adjustRangesForEdit<T extends RangeBounds>(
  ranges: T[],
  editLocation: number,
  deletedLength: number,
  insertedLength: number,
  inheritsReplacementAtStart: (range: T) => boolean = () => false
): T[] {
  if (deletedLength === 0 && insertedLength === 0) {
    return ranges;
  }

  if (deletedLength > 0) {
    const deleted = { start: editLocation, end: editLocation + deletedLength };
    for (const range of ranges) {
      applyReplacement(
        range,
        deleted,
        insertedLength,
        inheritsReplacementAtStart
      );
    }
  } else {
    for (const range of ranges) {
      applyInsertion(range, editLocation, insertedLength);
    }
  }

  return ranges.filter((range) => range.end > range.start);
}
