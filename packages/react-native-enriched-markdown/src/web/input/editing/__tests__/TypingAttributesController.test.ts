import { TypingAttributesController } from '../TypingAttributesController';
import { FormattingStore } from '../../formatting/FormattingStore';
import { createFormattingRange as range } from '../../model/inlineStyles';

describe('TypingAttributesController', () => {
  it('flips a caret toggle on and back off', () => {
    const typing = new TypingAttributesController(new FormattingStore());

    typing.toggleStyle('strong', 7);
    expect(typing.styles).toEqual(['strong']);
    typing.toggleStyle('strong', 7);
    expect(typing.styles).toEqual([]);
    expect(typing.styleRemovals).toEqual([]);
  });

  it('pends a removal when toggling off an active style at a caret', () => {
    const store = new FormattingStore();
    store.setRanges([range('strong', 0, 4)]);
    const typing = new TypingAttributesController(store);

    typing.toggleStyle('strong', 2);
    expect(typing.styleRemovals).toEqual(['strong']);
    expect(typing.isEffectiveStyleActive('strong', 2)).toBe(false);
  });

  // Review §2.4.1: inside a run the caret already carries a pending copy of
  // its style, seeded from the run. The first press has to unbold, not just
  // drop that copy and leave the style on.
  it('unbolds on the first press inside a run the caret inherited', () => {
    const store = new FormattingStore();
    store.setRanges([range('strong', 0, 4)]);
    const typing = new TypingAttributesController(store);
    typing.resetForSelectionChange({ start: 2, end: 2 });
    expect(typing.isEffectiveStyleActive('strong', 2)).toBe(true);

    typing.toggleStyle('strong', 2);

    expect(typing.isEffectiveStyleActive('strong', 2)).toBe(false);
    typing.toggleStyle('strong', 2);
    expect(typing.isEffectiveStyleActive('strong', 2)).toBe(true);
  });

  it('turns off a style inherited at the end of a run on the first press', () => {
    const store = new FormattingStore();
    store.setRanges([range('strong', 0, 4)]);
    const typing = new TypingAttributesController(store);
    typing.resetForSelectionChange({ start: 4, end: 4 });

    typing.toggleStyle('strong', 4);

    expect(typing.styles).toEqual([]);
    expect(typing.isEffectiveStyleActive('strong', 4)).toBe(false);
  });

  it('keeps pending styles apart per type', () => {
    const typing = new TypingAttributesController(new FormattingStore());

    typing.toggleStyle('strong', 7);
    typing.toggleStyle('em', 7);
    typing.toggleStyle('strong', 7);

    expect(typing.styles).toEqual(['em']);
  });

  describe('isEffectiveStyleActive', () => {
    it('reports a pending add active outside any stored run', () => {
      const typing = new TypingAttributesController(new FormattingStore());

      typing.toggleStyle('strong', 7);

      expect(typing.isEffectiveStyleActive('strong', 7)).toBe(true);
    });

    // A link carries a url, so it can never be a typing attribute; its answer
    // has to come from the store even when a pending entry of the same name
    // somehow exists.
    it('answers for a link from the store alone', () => {
      const store = new FormattingStore();
      store.setRanges([range('link', 0, 4)]);
      const typing = new TypingAttributesController(store);

      expect(typing.isEffectiveStyleActive('link', 2)).toBe(true);
      expect(typing.isEffectiveStyleActive('link', 7)).toBe(false);
    });

    it('falls through to the store with nothing pending', () => {
      const store = new FormattingStore();
      store.setRanges([range('em', 0, 4)]);
      const typing = new TypingAttributesController(store);

      expect(typing.isEffectiveStyleActive('em', 2)).toBe(true);
      expect(typing.isEffectiveStyleActive('em', 7)).toBe(false);
    });
  });

  describe('resetForSelectionChange', () => {
    it('inherits the run the caret sits just after', () => {
      const store = new FormattingStore();
      store.setRanges([range('strong', 0, 4)]);
      const typing = new TypingAttributesController(store);

      // Caret at the end of the run: typing on continues it.
      typing.resetForSelectionChange({ start: 4, end: 4 });

      expect(typing.styles).toEqual(['strong']);
    });

    it('inherits nothing at a caret outside every run', () => {
      const store = new FormattingStore();
      store.setRanges([range('strong', 0, 4)]);
      const typing = new TypingAttributesController(store);

      typing.resetForSelectionChange({ start: 7, end: 7 });

      expect(typing.styles).toEqual([]);
    });

    // A caret at offset 0 has nothing before it to inherit from, however the
    // document starts.
    it('inherits nothing at the start of the document', () => {
      const store = new FormattingStore();
      store.setRanges([range('strong', 0, 4)]);
      const typing = new TypingAttributesController(store);

      typing.resetForSelectionChange({ start: 0, end: 0 });

      expect(typing.styles).toEqual([]);
    });

    it('takes the styles active at the start of a selection', () => {
      const store = new FormattingStore();
      store.setRanges([range('strong', 0, 8), range('em', 6, 8)]);
      const typing = new TypingAttributesController(store);

      typing.resetForSelectionChange({ start: 2, end: 8 });

      expect(typing.styles.sort()).toEqual(['strong']);
    });

    it('drops whatever was pending before the selection moved', () => {
      const typing = new TypingAttributesController(new FormattingStore());

      typing.toggleStyle('strong', 7);
      typing.toggleStyle('em', 7);
      typing.resetForSelectionChange({ start: 7, end: 7 });

      expect(typing.styles).toEqual([]);
      expect(typing.styleRemovals).toEqual([]);
    });

    it('rebuilds every typing attribute, not just the first', () => {
      const store = new FormattingStore();
      store.setRanges([
        range('strong', 0, 4),
        range('em', 0, 4),
        range('underline', 0, 4),
        range('strikethrough', 0, 4),
        range('spoiler', 0, 4),
      ]);
      const typing = new TypingAttributesController(store);

      typing.resetForSelectionChange({ start: 2, end: 2 });

      expect([...typing.styles].sort()).toEqual([
        'em',
        'spoiler',
        'strikethrough',
        'strong',
        'underline',
      ]);
    });

    // A link is not a typing attribute, so it must never be inherited: the
    // next character typed after one would otherwise join it.
    it('never inherits a link', () => {
      const store = new FormattingStore();
      store.setRanges([range('link', 0, 4)]);
      const typing = new TypingAttributesController(store);

      typing.resetForSelectionChange({ start: 4, end: 4 });

      expect(typing.styles).toEqual([]);
    });
  });
});
