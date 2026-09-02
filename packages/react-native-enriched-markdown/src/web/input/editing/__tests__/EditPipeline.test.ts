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
