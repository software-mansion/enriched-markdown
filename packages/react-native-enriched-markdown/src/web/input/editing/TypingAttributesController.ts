import type { FormattingStore } from '../formatting/FormattingStore';
import {
  TYPING_ATTRIBUTE_STYLES,
  type InputStyleType,
} from '../model/inlineStyles';
import type { RangeBounds } from '../model/rangeBounds';

// Holds the styles the caret carries into the next keystroke. With a
// selection the store already changed, so nothing pends; with a caret a
// toggle is remembered until the next character or selection move.
export class TypingAttributesController {
  private readonly formattingStore: FormattingStore;
  private readonly pendingStyles = new Set<InputStyleType>();
  private readonly pendingStyleRemovals = new Set<InputStyleType>();

  constructor(formattingStore: FormattingStore) {
    this.formattingStore = formattingStore;
  }

  get styles(): InputStyleType[] {
    return [...this.pendingStyles];
  }

  get styleRemovals(): InputStyleType[] {
    return [...this.pendingStyleRemovals];
  }

  isEffectiveStyleActive(type: InputStyleType, position: number): boolean {
    if (this.pendingStyleRemovals.has(type)) {
      return false;
    }
    if (this.pendingStyles.has(type)) {
      return true;
    }
    return this.formattingStore.isStyleActive(type, position);
  }

  toggleStyle(
    type: InputStyleType,
    wasActive: boolean,
    hasSelection: boolean
  ): void {
    if (hasSelection) {
      this.pendingStyles.delete(type);
      this.pendingStyleRemovals.delete(type);
      return;
    }
    if (this.pendingStyleRemovals.delete(type)) {
      return;
    }
    if (this.pendingStyles.delete(type)) {
      return;
    }
    if (wasActive) {
      this.pendingStyleRemovals.add(type);
    } else {
      this.pendingStyles.add(type);
    }
  }

  // Rebuilds the pending styles from the caret's surroundings after the
  // selection moves: the styles a plain insert there would inherit.
  resetForSelectionChange(selection: RangeBounds): void {
    this.pendingStyles.clear();
    this.pendingStyleRemovals.clear();
    if (selection.start !== selection.end) {
      for (const type of TYPING_ATTRIBUTE_STYLES) {
        if (this.formattingStore.isStyleActive(type, selection.start)) {
          this.pendingStyles.add(type);
        }
      }
      return;
    }
    for (const type of TYPING_ATTRIBUTE_STYLES) {
      if (this.formattingStore.isStyleAdjacentBefore(type, selection.start)) {
        this.pendingStyles.add(type);
      }
    }
  }
}
