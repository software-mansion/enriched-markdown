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
