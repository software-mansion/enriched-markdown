import { adjustRangesForEdit } from '../RangeEditAdjustment';
import type { RangeBounds } from '../../model/rangeBounds';

// Running example: "The world is big" with a styled range on "world" (4-9).
//   T  h  e  _  w  o  r  l  d  _  i  s  _  b  i  g
//   0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15
const r = (start: number, end: number): RangeBounds => ({ start, end });

describe('adjustRangesForEdit', () => {
  it('returns ranges unchanged for a no-op edit', () => {
    expect(adjustRangesForEdit([r(4, 9)], 2, 0, 0)).toEqual([r(4, 9)]);
  });

  it('insert shifts ranges at or after the edit, grows ranges around it', () => {
    // Typing 2 chars before "world" shifts the whole range right.
    expect(adjustRangesForEdit([r(4, 9)], 1, 0, 2)).toEqual([r(6, 11)]);
    // At the range start the typed characters stay outside the style.
    expect(adjustRangesForEdit([r(4, 9)], 4, 0, 2)).toEqual([r(6, 11)]);
    // Inside the range the style grows around the typed characters.
    expect(adjustRangesForEdit([r(4, 9)], 6, 0, 2)).toEqual([r(4, 11)]);
    // At the range end they stay outside too — continuing a style while typing
    // is the pending-styles layer's call (it can be toggled off, and links
    // must never extend).
    expect(adjustRangesForEdit([r(4, 9)], 9, 0, 2)).toEqual([r(4, 9)]);
  });

  it('insert at range start grows the range when growsAtStartOnInsert allows it', () => {
    // Block ranges own their whole line, so the typed text joins the range.
    const result = adjustRangesForEdit(
      [r(4, 9)],
      4,
      0,
      2,
      undefined,
      () => true
    );

    expect(result).toEqual([r(4, 11)]);
  });

  it('delete before the range shifts it left; delete after leaves it alone', () => {
    expect(adjustRangesForEdit([r(4, 9)], 1, 2, 0)).toEqual([r(2, 7)]);
    expect(adjustRangesForEdit([r(4, 9)], 10, 3, 0)).toEqual([r(4, 9)]);
    // A replacement before the range shifts it by the net length change.
    expect(adjustRangesForEdit([r(4, 9)], 1, 2, 1)).toEqual([r(3, 8)]);
  });

  it('delete inside the range shrinks it; replacement inside resizes it', () => {
    expect(adjustRangesForEdit([r(4, 9)], 5, 2, 0)).toEqual([r(4, 7)]);
    expect(adjustRangesForEdit([r(4, 9)], 5, 2, 3)).toEqual([r(4, 10)]);
  });

  it('drops a range fully covered by the deletion', () => {
    expect(adjustRangesForEdit([r(4, 9)], 3, 10, 0)).toEqual([]);
  });

  it('replacement of the whole range keeps the style only when it inherits', () => {
    // Autocorrect swaps "world" for "worlds": the new text keeps the style.
    expect(adjustRangesForEdit([r(4, 9)], 4, 5, 6, () => true)).toEqual([
      r(4, 10),
    ]);
    // Links do not inherit — replaced text is no longer that link.
    expect(adjustRangesForEdit([r(4, 9)], 4, 5, 6, () => false)).toEqual([]);
  });

  it('clips the tail when the deletion overlaps the range end', () => {
    expect(adjustRangesForEdit([r(4, 9)], 7, 6, 0)).toEqual([r(4, 7)]);
  });

  it('clips the head when the deletion overlaps the range start', () => {
    expect(adjustRangesForEdit([r(4, 9)], 2, 4, 0)).toEqual([r(2, 5)]);
    // Autocorrect over the word start ("wo" -> "Wo") keeps the whole style.
    expect(adjustRangesForEdit([r(4, 9)], 4, 2, 2, () => true)).toEqual([
      r(4, 9),
    ]);
  });

  it('adjusts every range in the list independently', () => {
    // One deletion, three fates: untouched, swallowed, head-clipped.
    const ranges = [r(0, 4), r(5, 8), r(10, 12)];

    expect(adjustRangesForEdit(ranges, 4, 7, 0)).toEqual([r(0, 4), r(4, 5)]);
  });
});
