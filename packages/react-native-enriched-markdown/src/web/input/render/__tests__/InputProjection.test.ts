import {
  computeStyleRuns,
  ParagraphProjector,
  projectParagraphs,
} from '../InputProjection';
import { FormattingStore } from '../../formatting/FormattingStore';
import { createFormattingRange as range } from '../../model/inlineStyles';
import { createBlockRange as block } from '../../model/blocks';

describe('computeStyleRuns', () => {
  it('returns a single plain run when no ranges overlap the segment', () => {
    expect(computeStyleRuns([], 0, 5)).toEqual([
      { startInLine: 0, endInLine: 5, styles: [] },
    ]);
    expect(computeStyleRuns([range('strong', 10, 14)], 0, 5)).toEqual([
      { startInLine: 0, endInLine: 5, styles: [] },
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
      { startInLine: 0, endInLine: 4, styles: [] },
      { startInLine: 4, endInLine: 10, styles: ['strong'] },
      { startInLine: 10, endInLine: 12, styles: ['strong', 'em'] },
      { startInLine: 12, endInLine: 16, styles: ['strong'] },
    ]);
  });

  it('orders a run’s styles canonically regardless of range order', () => {
    const runs = computeStyleRuns(
      [range('em', 0, 4), range('strong', 0, 4)],
      0,
      4
    );
    expect(runs).toEqual([
      { startInLine: 0, endInLine: 4, styles: ['strong', 'em'] },
    ]);
  });

  it('merges adjacent runs with identical styles', () => {
    const runs = computeStyleRuns(
      [range('strong', 0, 3), range('strong', 3, 6)],
      0,
      6
    );
    expect(runs).toEqual([
      { startInLine: 0, endInLine: 6, styles: ['strong'] },
    ]);
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
      { startInLine: 0, endInLine: 3, styles: ['link'], url: 'https://a.dev' },
      { startInLine: 3, endInLine: 6, styles: ['link'], url: 'https://b.dev' },
    ]);
  });

  it('clips ranges to the line and offsets runs from its start', () => {
    const runs = computeStyleRuns([range('strong', 0, 20)], 5, 10);
    expect(runs).toEqual([
      { startInLine: 0, endInLine: 5, styles: ['strong'] },
    ]);
  });

  it('ignores zero-length ranges', () => {
    const runs = computeStyleRuns([range('strong', 2, 2)], 0, 5);
    expect(runs).toEqual([{ startInLine: 0, endInLine: 5, styles: [] }]);
  });
});

describe('projectParagraphs', () => {
  it('projects an empty document as a single empty paragraph', () => {
    expect(projectParagraphs('', [], [])).toEqual({
      paragraphs: [
        { text: '', blockType: 'paragraph', level: 0, ordinal: 1, runs: [] },
      ],
      lineStarts: [0],
    });
  });

  it('defaults unclaimed lines to paragraphs with plain runs', () => {
    // "The world\nis big"
    expect(projectParagraphs('The world\nis big', [], [])).toEqual({
      paragraphs: [
        {
          text: 'The world',
          blockType: 'paragraph',
          level: 0,
          ordinal: 1,
          runs: [{ startInLine: 0, endInLine: 9, styles: [] }],
        },
        {
          text: 'is big',
          blockType: 'paragraph',
          level: 0,
          ordinal: 1,
          runs: [{ startInLine: 0, endInLine: 6, styles: [] }],
        },
      ],
      lineStarts: [0, 10],
    });
  });

  it('keeps the empty trailing paragraph after a final newline', () => {
    const { paragraphs, lineStarts } = projectParagraphs('end\n', [], []);
    expect(paragraphs).toHaveLength(2);
    expect(paragraphs[1]).toEqual({
      text: '',
      blockType: 'paragraph',
      level: 0,
      ordinal: 1,
      runs: [],
    });
    expect(lineStarts).toEqual([0, 4]);
  });

  it('resolves block metadata for claimed lines', () => {
    // "Rebase\n- fetch\n- merge" with h1 + two list items.
    const text = 'Rebase\nfetch\nmerge';
    const blocks = [
      block('h1', 0, 6, 1),
      block('unordered-list-item', 7, 12, 0),
      { ...block('ordered-list-item', 13, 18, 1), ordinal: 3 },
    ];
    const { paragraphs } = projectParagraphs(text, [], blocks);
    expect(paragraphs.map((p) => [p.blockType, p.level, p.ordinal])).toEqual([
      ['h1', 1, 1],
      ['unordered-list-item', 0, 1],
      ['ordered-list-item', 1, 3],
    ]);
  });

  it('lets a zero-length anchor claim its empty line', () => {
    // Emptied heading between two paragraphs.
    const { paragraphs } = projectParagraphs(
      'a\n\nb',
      [],
      [block('h2', 2, 2, 2)]
    );
    expect(paragraphs.map((p) => p.blockType)).toEqual([
      'paragraph',
      'h2',
      'paragraph',
    ]);
  });

  it('computes runs per line, clipping ranges that span the newline', () => {
    const { paragraphs } = projectParagraphs(
      'ab\ncd',
      [range('strong', 1, 4)],
      []
    );
    expect(paragraphs[0]!.runs).toEqual([
      { startInLine: 0, endInLine: 1, styles: [] },
      { startInLine: 1, endInLine: 2, styles: ['strong'] },
    ]);
    expect(paragraphs[1]!.runs).toEqual([
      { startInLine: 0, endInLine: 1, styles: ['strong'] },
      { startInLine: 1, endInLine: 2, styles: [] },
    ]);
  });
});

describe('ParagraphProjector', () => {
  // A formatting store and a projector over it, kept in step by `edit` the
  // way the host keeps them: the store follows the edit, then the hint.
  function setUp(text: string, ranges = [range('strong', 0, 1)]) {
    const formatting = new FormattingStore();
    formatting.setRanges(ranges);
    const projector = new ParagraphProjector(formatting);
    let current = text;
    const blocks: ReturnType<typeof block>[] = [];
    const project = () => projector.project(current, blocks);
    const edit = (start: number, deleted: number, inserted: string) => {
      current =
        current.slice(0, start) + inserted + current.slice(start + deleted);
      formatting.adjustForEdit(start, deleted, inserted.length);
      projector.textEdited(start, deleted, inserted, current);
    };
    return {
      formatting,
      projector,
      blocks,
      project,
      edit,
      text: () => current,
    };
  }

  it('keeps every untouched line object and shifts the line starts', () => {
    const model = setUp('aa\nbb\ncc\ndd');
    const before = model.project().paragraphs;
    model.edit(4, 0, 'XYZ');
    const after = model.project();
    expect(after).toEqual(
      projectParagraphs(model.text(), model.formatting.allRanges, [])
    );
    expect(after.paragraphs[0]).toBe(before[0]);
    expect(after.paragraphs[1]).not.toBe(before[1]);
    expect(after.paragraphs[2]).toBe(before[2]);
    expect(after.paragraphs[3]).toBe(before[3]);
    expect(after.lineStarts).toEqual([0, 3, 9, 12]);
  });

  it('splits and joins lines', () => {
    const model = setUp('aa\nbb\ncc');
    model.project();
    model.edit(4, 0, '1\n2\n');
    expect(model.project()).toEqual(
      projectParagraphs(model.text(), model.formatting.allRanges, [])
    );
    // From inside the first line to inside the last.
    model.edit(1, model.text().length - 2, '');
    expect(model.project()).toEqual(
      projectParagraphs(model.text(), model.formatting.allRanges, [])
    );
  });

  it('restyles only the lines a style change touched', () => {
    const model = setUp('aa\nbb\ncc', []);
    const before = model.project().paragraphs;
    model.formatting.toggleStyle('em', 4, 5);
    model.projector.stylesChanged(4, 5);
    const after = model.project();
    expect(after.paragraphs[1]!.runs).toEqual([
      { startInLine: 0, endInLine: 1, styles: [] },
      { startInLine: 1, endInLine: 2, styles: ['em'] },
    ]);
    expect(after.paragraphs[0]).toBe(before[0]);
    expect(after.paragraphs[2]).toBe(before[2]);
  });

  it('re-reads block metadata for kept lines, keeping their runs', () => {
    const model = setUp('aa\nbb');
    const before = model.project().paragraphs;
    model.blocks.push({ ...block('ordered-list-item', 3, 5, 0), ordinal: 4 });
    const after = model.project().paragraphs;
    expect(after[0]).toBe(before[0]);
    expect(after[1]).toEqual({
      ...before[1],
      blockType: 'ordered-list-item',
      ordinal: 4,
    });
    expect(after[1]!.runs).toBe(before[1]!.runs);
  });

  it('projects every line again after a change it was not told about', () => {
    const error = jest.spyOn(console, 'error').mockImplementation(() => {});
    try {
      const model = setUp('aa\nbb');
      model.project();
      model.formatting.toggleStyle('em', 3, 5);
      expect(model.project()).toEqual(
        projectParagraphs(model.text(), model.formatting.allRanges, [])
      );
      expect(error).toHaveBeenCalledWith(
        expect.stringContaining('without a projection hint')
      );
    } finally {
      error.mockRestore();
    }
  });

  it('starts over silently after `invalidate`', () => {
    const error = jest.spyOn(console, 'error').mockImplementation(() => {});
    try {
      const model = setUp('aa\nbb');
      const before = model.project().paragraphs;
      model.formatting.setRanges([range('em', 0, 5)]);
      model.projector.invalidate();
      const after = model.project();
      expect(after).toEqual(
        projectParagraphs(model.text(), model.formatting.allRanges, [])
      );
      expect(after.paragraphs[1]).not.toBe(before[1]);
      expect(error).not.toHaveBeenCalled();
    } finally {
      error.mockRestore();
    }
  });
});
