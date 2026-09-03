import { EditPipeline, type EditContext } from '../EditPipeline';
import { FormattingStore } from '../../formatting/FormattingStore';
import { BlockStore } from '../../formatting/BlockStore';
import { createFormattingRange as range } from '../../model/inlineStyles';
import { createBlockRange as block } from '../../model/blocks';

function context(partial: Partial<EditContext>): EditContext {
  return {
    editStart: 0,
    deletedText: '',
    insertedText: '',
    pendingStyles: [],
    pendingStyleRemovals: [],
    ...partial,
  };
}

describe('EditPipeline', () => {
  it('walks both stores through one edit and renumbers ordinals', () => {
    // "fetch\nmerge" as an ordered list, strong on "merge"; delete line one.
    const styles = new FormattingStore();
    styles.setRanges([range('strong', 6, 11)]);
    const blocks = new BlockStore();
    blocks.setRanges([
      block('ordered-list-item', 0, 5),
      { ...block('ordered-list-item', 6, 11), ordinal: 2 },
    ]);
    const pipeline = new EditPipeline(styles, blocks);

    const touchedNewline = pipeline.processTextChange(
      'merge',
      context({ editStart: 0, deletedText: 'fetch\n' })
    );

    expect(touchedNewline).toBe(true);
    expect(styles.allRanges).toEqual([range('strong', 0, 5)]);
    expect(blocks.allRanges).toEqual([block('ordered-list-item', 0, 5)]);
  });

  it('wraps a glyph insert in the pending styles and carves the removals', () => {
    const styles = new FormattingStore();
    styles.setRanges([range('em', 0, 2)]);
    const pipeline = new EditPipeline(styles, new BlockStore());

    const touchedNewline = pipeline.processTextChange(
      'axb',
      context({
        editStart: 1,
        insertedText: 'x',
        pendingStyles: ['strong'],
        pendingStyleRemovals: ['em'],
      })
    );

    expect(touchedNewline).toBe(false);
    expect(styles.allRanges).toEqual([
      range('em', 0, 1),
      range('strong', 1, 2),
      range('em', 2, 3),
    ]);
  });

  it('never wraps a bare newline in pending styles', () => {
    const styles = new FormattingStore();
    const pipeline = new EditPipeline(styles, new BlockStore());

    const touchedNewline = pipeline.processTextChange(
      'a\nb',
      context({ editStart: 1, insertedText: '\n', pendingStyles: ['strong'] })
    );

    expect(touchedNewline).toBe(true);
    expect(styles.allRanges).toEqual([]);
  });
});

describe('EditPipeline on enter', () => {
  it('keeps nested items nested when a list continues above them', () => {
    // "- stack\n   - review": press Enter at the end of "stack".
    const blocks = new BlockStore();
    blocks.setRanges([
      block('unordered-list-item', 0, 5, 0),
      block('unordered-list-item', 6, 12, 1),
    ]);
    const pipeline = new EditPipeline(new FormattingStore(), blocks);

    pipeline.processTextChange(
      'stack\n\nreview',
      context({ editStart: 5, insertedText: '\n' })
    );

    // The fresh empty line continues the outer list and "review" below it
    // stays at depth 1: continuation must precede normalization, or the
    // depth clamp sees a gap and flattens it.
    expect(blocks.allRanges.map((b) => [b.start, b.level])).toEqual([
      [0, 0],
      [6, 0],
      [7, 1],
    ]);
  });

  it('keeps both halves in the list when an item is split mid-word', () => {
    // "- stack\n   - review": press Enter inside "review".
    const blocks = new BlockStore();
    blocks.setRanges([
      block('unordered-list-item', 0, 5, 0),
      block('unordered-list-item', 6, 12, 1),
    ]);
    const pipeline = new EditPipeline(new FormattingStore(), blocks);

    pipeline.processTextChange(
      'stack\nre\nview',
      context({ editStart: 8, insertedText: '\n' })
    );

    // The adjusted item spans the newline until it is snapped back; without
    // that the fresh anchor removes it and "re" drops out of the list.
    expect(blocks.allRanges.map((b) => [b.start, b.end, b.level])).toEqual([
      [0, 5, 0],
      [6, 8, 1],
      [9, 13, 1],
    ]);
  });
});
