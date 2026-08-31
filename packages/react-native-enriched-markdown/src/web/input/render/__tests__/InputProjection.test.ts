import { computeStyleRuns } from '../InputProjection';
import { createFormattingRange as range } from '../../model/inlineStyles';

describe('computeStyleRuns', () => {
  it('returns a single plain run when no ranges overlap the segment', () => {
    expect(computeStyleRuns([], 0, 5)).toEqual([
      { start: 0, end: 5, styles: [] },
    ]);
    expect(computeStyleRuns([range('strong', 10, 14)], 0, 5)).toEqual([
      { start: 0, end: 5, styles: [] },
    ]);
  });

  it('returns no runs for an empty segment', () => {
    expect(computeStyleRuns([range('strong', 0, 4)], 3, 3)).toEqual([]);
  });

  it('cuts the text at every range boundary', () => {
    // "the world is big": bold over "world is big", italic over "is".
    const runs = computeStyleRuns(
      [range('strong', 4, 16), range('em', 10, 12)],
      0,
      16
    );
    expect(runs).toEqual([
      { start: 0, end: 4, styles: [] },
      { start: 4, end: 10, styles: ['strong'] },
      { start: 10, end: 12, styles: ['strong', 'em'] },
      { start: 12, end: 16, styles: ['strong'] },
    ]);
  });

  it('orders a run’s styles canonically regardless of range order', () => {
    const runs = computeStyleRuns(
      [range('em', 0, 4), range('strong', 0, 4)],
      0,
      4
    );
    expect(runs).toEqual([{ start: 0, end: 4, styles: ['strong', 'em'] }]);
  });

  it('merges adjacent runs with identical styles', () => {
    const runs = computeStyleRuns(
      [range('strong', 0, 3), range('strong', 3, 6)],
      0,
      6
    );
    expect(runs).toEqual([{ start: 0, end: 6, styles: ['strong'] }]);
  });

  it('keeps adjacent links with different urls as separate runs', () => {
    const runs = computeStyleRuns(
      [
        range('link', 0, 3, 'https://a.dev'),
        range('link', 3, 6, 'https://b.dev'),
      ],
      0,
      6
    );
    expect(runs).toEqual([
      { start: 0, end: 3, styles: ['link'], url: 'https://a.dev' },
      { start: 3, end: 6, styles: ['link'], url: 'https://b.dev' },
    ]);
  });

  it('clips ranges to the segment bounds', () => {
    const runs = computeStyleRuns([range('strong', 0, 20)], 5, 10);
    expect(runs).toEqual([{ start: 5, end: 10, styles: ['strong'] }]);
  });

  it('ignores zero-length ranges', () => {
    const runs = computeStyleRuns([range('strong', 2, 2)], 0, 5);
    expect(runs).toEqual([{ start: 0, end: 5, styles: [] }]);
  });
});
