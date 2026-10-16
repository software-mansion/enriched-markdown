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

    pipeline.processTextChange(
      'merge',
      context({ editStart: 0, deletedText: 'fetch\n' })
    );

    expect(styles.allRanges).toEqual([range('strong', 0, 5)]);
    expect(blocks.allRanges).toEqual([block('ordered-list-item', 0, 5)]);
  });

  it('wraps a glyph insert in the pending styles and carves the removals', () => {
    const styles = new FormattingStore();
    styles.setRanges([range('em', 0, 2)]);
    const pipeline = new EditPipeline(styles, new BlockStore());

    pipeline.processTextChange(
      'axb',
      context({
        editStart: 1,
        insertedText: 'x',
        pendingStyles: ['strong'],
        pendingStyleRemovals: ['em'],
      })
    );

    expect(styles.allRanges).toEqual([
      range('em', 0, 1),
      range('strong', 1, 2),
      range('em', 2, 3),
    ]);
  });

  it('never wraps a bare newline in pending styles', () => {
    const styles = new FormattingStore();
    const pipeline = new EditPipeline(styles, new BlockStore());

    pipeline.processTextChange(
      'a\nb',
      context({ editStart: 1, insertedText: '\n', pendingStyles: ['strong'] })
    );

    expect(styles.allRanges).toEqual([]);
  });

  // A paste or a dictated phrase arrives as one multi-line insert; a
  // caret-level style belongs only to the first of those lines.
  it('clips a pending style at the first newline of a mixed insert', () => {
    const styles = new FormattingStore();
    const pipeline = new EditPipeline(styles, new BlockStore());

    pipeline.processTextChange(
      'xa\nby',
      context({ editStart: 1, insertedText: 'a\nb', pendingStyles: ['strong'] })
    );

    expect(styles.allRanges).toEqual([range('strong', 1, 2)]);
  });

  it('still carves removals across the whole multi-line insert', () => {
    const styles = new FormattingStore();
    styles.setRanges([range('em', 0, 2)]);
    const pipeline = new EditPipeline(styles, new BlockStore());

    pipeline.processTextChange(
      'xa\nby',
      context({
        editStart: 1,
        insertedText: 'a\nb',
        pendingStyleRemovals: ['em'],
      })
    );

    expect(styles.allRanges).toEqual([range('em', 0, 1), range('em', 4, 5)]);
  });

  describe('orphaned block anchors', () => {
    // Backspace at the start of a block line merges it into the line above.
    // The anchor lands mid-line, and without the prune `normalizeToLineBounds`
    // snaps it onto the merged line and spreads it over that line's text -
    // promoting a plain paragraph into a heading or a bullet.
    it('drops a heading anchor merged into the paragraph above', () => {
      const blocks = new BlockStore();
      blocks.setRanges([{ ...block('h1', 2, 3), level: 1 }]);

      new EditPipeline(new FormattingStore(), blocks).processTextChange(
        'ab',
        context({ editStart: 1, deletedText: '\n' })
      );

      expect(blocks.allRanges).toEqual([]);
    });

    it('drops a list anchor merged into the paragraph above', () => {
      const blocks = new BlockStore();
      blocks.setRanges([block('unordered-list-item', 2, 3)]);

      new EditPipeline(new FormattingStore(), blocks).processTextChange(
        'ab',
        context({ editStart: 1, deletedText: '\n' })
      );

      expect(blocks.allRanges).toEqual([]);
    });

    it('drops an emptied heading anchor merged upwards', () => {
      const blocks = new BlockStore();
      blocks.setRanges([{ ...block('h2', 3, 3), level: 2 }]);

      new EditPipeline(new FormattingStore(), blocks).processTextChange(
        'ab',
        context({ editStart: 2, deletedText: '\n' })
      );

      expect(blocks.allRanges).toEqual([]);
    });

    // Delete-forward at the end of a line joins the next one up, so the same
    // orphan arrives from the other direction.
    it('drops a heading joined upwards by a forward delete', () => {
      const blocks = new BlockStore();
      blocks.setRanges([{ ...block('h1', 3, 5), level: 1 }]);

      new EditPipeline(new FormattingStore(), blocks).processTextChange(
        'abcd',
        context({ editStart: 2, deletedText: '\n' })
      );

      expect(blocks.allRanges).toEqual([]);
    });

    it('keeps a legitimate block on the line merged into', () => {
      const blocks = new BlockStore();
      blocks.setRanges([
        { ...block('h1', 0, 2), level: 1 },
        { ...block('h2', 3, 3), level: 2 },
      ]);

      new EditPipeline(new FormattingStore(), blocks).processTextChange(
        'ab',
        context({ editStart: 2, deletedText: '\n' })
      );

      expect(blocks.allRanges).toEqual([{ ...block('h1', 0, 2), level: 1 }]);
    });

    // Web lets an insert at a line start shift the range off the line start
    // and relies on normalize to snap it back, so the prune has to stay out
    // of the way of inserts or it would delete the block on every keystroke
    // there.
    it('leaves a block alone when typing at its line start', () => {
      const blocks = new BlockStore();
      blocks.setRanges([{ ...block('h1', 0, 2), level: 1 }]);

      new EditPipeline(new FormattingStore(), blocks).processTextChange(
        'xab',
        context({ editStart: 0, insertedText: 'x' })
      );

      expect(blocks.allRanges).toEqual([{ ...block('h1', 0, 3), level: 1 }]);
    });

    it('leaves a block alone on Enter at its line start', () => {
      const blocks = new BlockStore();
      blocks.setRanges([{ ...block('h1', 0, 2), level: 1 }]);

      new EditPipeline(new FormattingStore(), blocks).processTextChange(
        '\nab',
        context({ editStart: 0, insertedText: '\n' })
      );

      expect(blocks.allRanges).toEqual([{ ...block('h1', 1, 3), level: 1 }]);
    });
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
