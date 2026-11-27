import type { FormattingStore } from '../formatting/FormattingStore';
import {
  TYPING_ATTRIBUTE_STYLES,
  type InputStyleType,
  type PendingStyleType,
} from '../model/inlineStyles';
import type { RangeBounds } from '../model/rangeBounds';

// Holds the styles the caret carries into the next keystroke. With a
// selection they mirror the store at its start; with a caret a toggle is
// remembered until the next character or selection move.
export class TypingAttributesController {
  private readonly formattingStore: FormattingStore;
  private readonly pendingStyles = new Set<PendingStyleType>();
  private readonly pendingStyleRemovals = new Set<PendingStyleType>();

  constructor(formattingStore: FormattingStore) {
    this.formattingStore = formattingStore;
  }

  get styles(): PendingStyleType[] {
    return [...this.pendingStyles];
  }

  get styleRemovals(): PendingStyleType[] {
    return [...this.pendingStyleRemovals];
  }

  // Takes any style, not just a pendable one, because the state a toolbar
  // reads covers links too. A link never pends (see `PendingStyleType`), so
  // its answer comes straight from the store.
  isEffectiveStyleActive(type: InputStyleType, position: number): boolean {
    if (type !== 'link') {
      if (this.pendingStyleRemovals.has(type)) {
        return false;
      }
      if (this.pendingStyles.has(type)) {
        return true;
      }
    }
    return this.formattingStore.isStyleActive(type, position);
  }

  // A toggle at a caret (`caret` is its offset) flips what the next keystroke
  // would get - the effective style, pending sets included - rather than
  // undoing the last pending change: inside a bold run the caret already
  // carries a pending bold seeded from the run, and the first press has to
  // unbold, not just drop that copy. A toggle over a selection changes the
  // store instead and is followed by `resetForSelectionChange`.
  toggleStyle(type: PendingStyleType, caret: number): void {
    const wasActive = this.isEffectiveStyleActive(type, caret);
    this.pendingStyles.delete(type);
    this.pendingStyleRemovals.delete(type);
    const storeActive = this.formattingStore.isStyleActive(type, caret);
    if (wasActive && storeActive) {
      this.pendingStyleRemovals.add(type);
    } else if (!wasActive && !storeActive) {
      this.pendingStyles.add(type);
    }
  }

  // The styles a plain insert at the new selection would inherit.
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
