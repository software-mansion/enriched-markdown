import { FormattingStore } from '../FormattingStore';
import type { FormattingRange } from '../types';

const strong = (start: number, end: number): FormattingRange => ({
  type: 'strong',
  start,
  end,
});

const link = (start: number, end: number, url: string): FormattingRange => ({
  type: 'link',
  start,
  end,
  url,
});

describe('FormattingStore', () => {
  let store: FormattingStore;

  beforeEach(() => {
    store = new FormattingStore();
  });

  it('reports a style active inside its range, with exclusive end', () => {
    store.addRange(strong(4, 9));

    expect(store.isStyleActive('strong', 4)).toBe(true);
    expect(store.isStyleActive('strong', 8)).toBe(true);
    expect(store.isStyleActive('strong', 3)).toBe(false);
    expect(store.isStyleActive('strong', 9)).toBe(false);
    expect(store.isStyleActive('em', 5)).toBe(false);
  });

  it('addRange merges overlapping and touching ranges of the same type only', () => {
    store.addRange(strong(4, 9));
    store.addRange(strong(7, 12));
    store.addRange(strong(12, 15));
    store.addRange({ type: 'em', start: 5, end: 8 });

    expect(store.allRanges).toEqual([
      strong(4, 15),
      { type: 'em', start: 5, end: 8 },
    ]);
  });

  it('keeps ranges sorted by start on add and on setRanges', () => {
    store.addRange(strong(20, 25));
    store.addRange(strong(0, 3));
    store.addRange(strong(10, 12));
    expect(store.allRanges.map((r) => r.start)).toEqual([0, 10, 20]);

    store.setRanges([strong(10, 12), strong(0, 3)]);
    expect(store.allRanges.map((r) => r.start)).toEqual([0, 10]);
  });

  it('merged range takes the new url', () => {
    store.addRange(link(0, 5, 'https://old.example'));
    store.addRange(link(3, 8, 'https://new.example'));

    expect(store.allRanges).toEqual([link(0, 8, 'https://new.example')]);
  });

  it('isStyleActiveInRange requires a shared character, not a shared boundary', () => {
    store.addRange(strong(4, 9));

    expect(store.isStyleActiveInRange('strong', 8, 20)).toBe(true);
    expect(store.isStyleActiveInRange('strong', 9, 20)).toBe(false);
    expect(store.isStyleActiveInRange('strong', 0, 4)).toBe(false);
  });

  it('isStyleAdjacentBefore is true inside and right after a run', () => {
    store.addRange(strong(4, 9));

    expect(store.isStyleAdjacentBefore('strong', 6)).toBe(true);
    expect(store.isStyleAdjacentBefore('strong', 9)).toBe(true);
    expect(store.isStyleAdjacentBefore('strong', 10)).toBe(false);
    expect(store.isStyleAdjacentBefore('strong', 0)).toBe(false);
  });

  it('isStyleFullyActive accepts coverage from touching ranges, rejects gaps', () => {
    store.setRanges([strong(0, 5), strong(5, 10)]);
    expect(store.isStyleFullyActive('strong', 2, 8)).toBe(true);

    store.setRanges([strong(0, 4), strong(6, 10)]);
    expect(store.isStyleFullyActive('strong', 2, 8)).toBe(false);

    expect(store.isStyleFullyActive('strong', 3, 3)).toBe(true);
  });

  it('adjustForEdit coalesces bold runs joined by a deletion', () => {
    // "**foo** **bar**" — deleting the space leaves two touching bolds.
    store.setRanges([strong(0, 3), strong(4, 7)]);
    store.adjustForEdit(3, 1, 0);

    expect(store.allRanges).toEqual([strong(0, 6)]);
  });

  it('adjustForEdit keeps touching links with different urls separate', () => {
    store.setRanges([
      link(0, 3, 'https://a.example'),
      link(4, 7, 'https://b.example'),
    ]);
    store.adjustForEdit(3, 1, 0);

    expect(store.allRanges).toEqual([
      link(0, 3, 'https://a.example'),
      link(3, 6, 'https://b.example'),
    ]);
  });

  it('adjustForEdit lets styles inherit a replacement but drops links', () => {
    store.setRanges([strong(4, 9)]);
    store.adjustForEdit(4, 5, 6);
    expect(store.allRanges).toEqual([strong(4, 10)]);

    store.setRanges([link(4, 9, 'https://a.example')]);
    store.adjustForEdit(4, 5, 6);
    expect(store.allRanges).toEqual([]);
  });

  it('adjustForEdit moves every range affected by the edit', () => {
    store.setRanges([strong(0, 3), { type: 'em', start: 5, end: 8 }]);
    store.adjustForEdit(4, 0, 2);

    expect(store.allRanges).toEqual([
      strong(0, 3),
      { type: 'em', start: 7, end: 10 },
    ]);
  });

  it('removeType splits a covering range, preserving url on remainders', () => {
    store.addRange(link(0, 10, 'https://a.example'));
    store.removeType('link', 4, 6);

    expect(store.allRanges).toEqual([
      link(0, 4, 'https://a.example'),
      link(6, 10, 'https://a.example'),
    ]);
  });

  it('removeType clips partial overlaps and drops fully covered ranges', () => {
    store.setRanges([strong(0, 10), strong(12, 14), strong(16, 30)]);
    store.removeType('strong', 6, 20);

    expect(store.allRanges).toEqual([strong(0, 6), strong(20, 30)]);
  });

  it('toggleStyle adds the style to a clean or partially covered selection', () => {
    // "The world": bold only "The", then toggle over "The wo" — everything
    // in the selection ends up bold (partial coverage means inactive).
    store.setRanges([strong(0, 3)]);
    const wasActive = store.toggleStyle('strong', 0, 6);

    expect(wasActive).toBe(false);
    expect(store.allRanges).toEqual([strong(0, 6)]);
  });

  it('toggleStyle removes the style from a fully covered selection', () => {
    store.setRanges([strong(0, 10)]);
    const wasActive = store.toggleStyle('strong', 2, 6);

    expect(wasActive).toBe(true);
    expect(store.allRanges).toEqual([strong(0, 2), strong(6, 10)]);
  });

  it('toggleStyle strips conflicting styles before adding', () => {
    store.setRanges([{ type: 'spoiler', start: 2, end: 8 }]);
    store.toggleStyle('link', 0, 6, new Set(['spoiler']));

    expect(store.allRanges).toEqual([
      { type: 'link', start: 0, end: 6 },
      { type: 'spoiler', start: 6, end: 8 },
    ]);
  });

  it('toggleStyle at a caret reports state without mutating', () => {
    store.setRanges([strong(4, 9)]);

    expect(store.toggleStyle('strong', 5, 5)).toBe(true);
    expect(store.toggleStyle('strong', 2, 2)).toBe(false);
    expect(store.allRanges).toEqual([strong(4, 9)]);
  });

  it('isToggleBlocked refuses toggling ON under a blocker, never OFF', () => {
    store.setRanges([{ type: 'spoiler', start: 0, end: 5 }, strong(0, 5)]);

    expect(store.isToggleBlocked('link', 2, new Set(['spoiler']))).toBe(true);
    // Toggling OFF an active style is never blocked.
    expect(store.isToggleBlocked('strong', 2, new Set(['spoiler']))).toBe(
      false
    );
    expect(store.isToggleBlocked('link', 8, new Set(['spoiler']))).toBe(false);
  });

  it('selectionAdjustedForAtomicLinks expands over partially selected links', () => {
    store.setRanges([
      link(0, 6, 'https://a.example'),
      link(6, 15, 'https://b.example'),
    ]);

    // Dragging from inside link A to inside link B swallows both whole.
    expect(store.selectionAdjustedForAtomicLinks(3, 10)).toEqual({
      start: 0,
      end: 15,
    });
    // A selection already aligned with link bounds needs no adjustment.
    expect(store.selectionAdjustedForAtomicLinks(0, 6)).toBeNull();
  });

  it('selectionAdjustedForAtomicLinks moves a caret out of a link', () => {
    store.setRanges([link(4, 9, 'https://a.example')]);

    expect(store.selectionAdjustedForAtomicLinks(6, 6)).toEqual({
      start: 9,
      end: 9,
    });
    // Caret at the link boundary stays put.
    expect(store.selectionAdjustedForAtomicLinks(4, 4)).toBeNull();
    expect(store.selectionAdjustedForAtomicLinks(9, 9)).toBeNull();
  });

  it('removeType leaves other types and boundary-touching ranges untouched', () => {
    store.setRanges([
      strong(0, 4),
      strong(6, 10),
      { type: 'em', start: 0, end: 10 },
    ]);
    store.removeType('strong', 4, 6);

    expect(store.allRanges).toEqual([
      strong(0, 4),
      { type: 'em', start: 0, end: 10 },
      strong(6, 10),
    ]);
  });
});
