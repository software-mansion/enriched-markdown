import { computeStyleRuns, projectParagraphs } from '../InputProjection';
import { createFormattingRange as range } from '../../model/inlineStyles';
import { createBlockRange as block } from '../../model/blocks';

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

describe('projectParagraphs', () => {
  it('projects an empty document as a single empty paragraph', () => {
    expect(projectParagraphs('', [], [])).toEqual([
      {
        start: 0,
        end: 0,
        blockType: 'paragraph',
        level: 0,
        ordinal: 1,
        runs: [],
      },
    ]);
  });

  it('defaults unclaimed lines to paragraphs with plain runs', () => {
    // "The world\nis big"
    const paragraphs = projectParagraphs('The world\nis big', [], []);
    expect(paragraphs).toEqual([
      {
        start: 0,
        end: 9,
        blockType: 'paragraph',
        level: 0,
        ordinal: 1,
        runs: [{ start: 0, end: 9, styles: [] }],
      },
      {
        start: 10,
        end: 16,
        blockType: 'paragraph',
        level: 0,
        ordinal: 1,
        runs: [{ start: 10, end: 16, styles: [] }],
      },
    ]);
  });

  it('keeps the empty trailing paragraph after a final newline', () => {
    const paragraphs = projectParagraphs('end\n', [], []);
    expect(paragraphs).toHaveLength(2);
    expect(paragraphs[1]).toEqual({
      start: 4,
      end: 4,
      blockType: 'paragraph',
      level: 0,
      ordinal: 1,
      runs: [],
    });
  });

  it('resolves block metadata for claimed lines', () => {
    // "Rebase\n- fetch\n- merge" with h1 + two list items.
    const text = 'Rebase\nfetch\nmerge';
    const blocks = [
      block('h1', 0, 6, 1),
      block('unordered-list-item', 7, 12, 0),
      { ...block('ordered-list-item', 13, 18, 1), ordinal: 3 },
    ];
    const paragraphs = projectParagraphs(text, [], blocks);
    expect(paragraphs.map((p) => [p.blockType, p.level, p.ordinal])).toEqual([
      ['h1', 1, 1],
      ['unordered-list-item', 0, 1],
      ['ordered-list-item', 1, 3],
    ]);
  });

  it('lets a zero-length anchor claim its empty line', () => {
    // Emptied heading between two paragraphs.
    const paragraphs = projectParagraphs('a\n\nb', [], [block('h2', 2, 2, 2)]);
    expect(paragraphs.map((p) => p.blockType)).toEqual([
      'paragraph',
      'h2',
      'paragraph',
    ]);
  });

  it('computes runs per line, clipping ranges that span the newline', () => {
    const paragraphs = projectParagraphs('ab\ncd', [range('strong', 1, 4)], []);
    expect(paragraphs[0]!.runs).toEqual([
      { start: 0, end: 1, styles: [] },
      { start: 1, end: 2, styles: ['strong'] },
    ]);
    expect(paragraphs[1]!.runs).toEqual([
      { start: 3, end: 4, styles: ['strong'] },
      { start: 4, end: 5, styles: [] },
    ]);
  });
});
