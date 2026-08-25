import type { RangeBounds } from '../model/rangeBounds';

type EditOverlap =
  | 'before-edit'
  | 'after-edit'
  | 'fully-deleted'
  | 'deleted-inside'
  | 'clipped-end'
  | 'clipped-start';

function classifyOverlap(
  rangeStart: number,
  rangeEnd: number,
  editLocation: number,
  deleteEnd: number
): EditOverlap {
  if (rangeEnd <= editLocation) return 'before-edit';
  if (rangeStart >= deleteEnd) return 'after-edit';
  if (rangeStart >= editLocation && rangeEnd <= deleteEnd) {
    return 'fully-deleted';
  }
  if (rangeStart < editLocation && rangeEnd > deleteEnd) {
    return 'deleted-inside';
  }
  return rangeStart < editLocation ? 'clipped-end' : 'clipped-start';
}

/**
 * Shift/clip logic applied to stored ranges after a text edit that replaced
 * `deletedLength` characters at `editLocation` with `insertedLength`
 * characters. Bounds are mutated in place; the returned array drops ranges
 * deleted outright or clipped to zero length.
 *
 * Insert-only edits at exactly `range.end` do NOT grow the range — whether
 * typed text continues a style is decided by the pending-styles layer, and
 * links must never auto-extend. An insert at
 * exactly `range.start` grows the range only when `growsAtStartOnInsert`
 * returns true (block ranges own their whole line); otherwise the range shifts
 * and the typed characters stay outside it (a character typed before a bold
 * run must not become bold).
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
  inheritsReplacementAtStart: (range: T) => boolean = () => false,
  growsAtStartOnInsert: (range: T) => boolean = () => false
): T[] {
  if (deletedLength === 0 && insertedLength === 0) {
    return ranges;
  }

  const deleteEnd = editLocation + deletedLength;
  const removed = new Set<T>();

  for (const range of ranges) {
    if (deletedLength > 0) {
      const inheritsReplacement =
        insertedLength > 0 &&
        range.start === editLocation &&
        inheritsReplacementAtStart(range);

      switch (
        classifyOverlap(range.start, range.end, editLocation, deleteEnd)
      ) {
        case 'before-edit':
          break;

        case 'after-edit':
          range.start += insertedLength - deletedLength;
          range.end += insertedLength - deletedLength;
          break;

        case 'fully-deleted':
          if (inheritsReplacement) {
            range.start = editLocation;
            range.end = editLocation + insertedLength;
          } else {
            removed.add(range);
          }
          break;

        case 'deleted-inside':
          range.end += insertedLength - deletedLength;
          break;

        case 'clipped-end': {
          const newEnd = editLocation + insertedLength;
          const newLength = newEnd > range.start ? newEnd - range.start : 0;
          range.end = range.start + newLength;
          if (newLength === 0) {
            removed.add(range);
          }
          break;
        }

        case 'clipped-start': {
          const charsClipped = deleteEnd - range.start;
          const survivingLength = range.end - range.start - charsClipped;
          if (inheritsReplacement) {
            range.start = editLocation;
            range.end = editLocation + insertedLength + survivingLength;
          } else {
            range.start = editLocation + insertedLength;
            range.end = range.start + survivingLength;
            if (survivingLength === 0) {
              removed.add(range);
            }
          }
          break;
        }
      }
    } else {
      if (range.start === editLocation && growsAtStartOnInsert(range)) {
        range.end += insertedLength;
      } else if (range.start >= editLocation) {
        range.start += insertedLength;
        range.end += insertedLength;
      } else if (editLocation > range.start && editLocation < range.end) {
        range.end += insertedLength;
      }
    }
  }

  return ranges.filter(
    (range) => !removed.has(range) && range.end - range.start > 0
  );
}
