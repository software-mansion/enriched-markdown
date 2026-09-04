import { TypingAttributesController } from '../TypingAttributesController';
import { FormattingStore } from '../../formatting/FormattingStore';
import { createFormattingRange as range } from '../../model/inlineStyles';

describe('TypingAttributesController', () => {
  it('remembers a caret toggle as a three-way switch', () => {
    const typing = new TypingAttributesController(new FormattingStore());

    // Off -> pending add; toggled again -> back to nothing.
    typing.toggleStyle('strong', false, false);
    expect(typing.styles).toEqual(['strong']);
    typing.toggleStyle('strong', false, false);
    expect(typing.styles).toEqual([]);
    expect(typing.styleRemovals).toEqual([]);
  });

  it('pends a removal when toggling off an active style at a caret', () => {
    const store = new FormattingStore();
    store.setRanges([range('strong', 0, 4)]);
    const typing = new TypingAttributesController(store);

    typing.toggleStyle('strong', true, false);
    expect(typing.styleRemovals).toEqual(['strong']);
    expect(typing.isEffectiveStyleActive('strong', 2)).toBe(false);
  });
});
