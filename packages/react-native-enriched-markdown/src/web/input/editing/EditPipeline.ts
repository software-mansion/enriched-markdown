import type { BlockStore } from '../formatting/BlockStore';
import type { FormattingStore } from '../formatting/FormattingStore';
import {
  createFormattingRange,
  type InputStyleType,
} from '../model/inlineStyles';

export interface EditContext {
  editStart: number;
  deletedText: string;
  insertedText: string;
  pendingStyles: readonly InputStyleType[];
  pendingStyleRemovals: readonly InputStyleType[];
}

export class EditPipeline {
  private readonly formattingStore: FormattingStore;
  private readonly blockStore: BlockStore;

  constructor(formattingStore: FormattingStore, blockStore: BlockStore) {
    this.formattingStore = formattingStore;
    this.blockStore = blockStore;
  }

  // `text` is the buffer after the edit. Returns whether a line boundary was
  // touched, so the caller knows to re-render beyond the edited line.
  processTextChange(text: string, context: EditContext): boolean {
    const { editStart, deletedText, insertedText } = context;

    this.formattingStore.adjustForEdit(
      editStart,
      deletedText.length,
      insertedText.length
    );
    this.blockStore.adjustForEdit(
      editStart,
      deletedText.length,
      insertedText.length
    );
    this.blockStore.normalizeToLineBounds(text);

    if (insertedText.length > 0) {
      this.applyPendingStyles(context);
    }

    return deletedText.includes('\n') || insertedText.includes('\n');
  }

  private applyPendingStyles(context: EditContext): void {
    const { editStart, insertedText, pendingStyles, pendingStyleRemovals } =
      context;
    const insertEnd = editStart + insertedText.length;

    // A newline-only insert gains no pending styles, but removals still
    // apply to it, so a style cannot flow across the new line boundary.
    const hasGlyphContent = /[^\n]/.test(insertedText);
    if (hasGlyphContent) {
      for (const type of pendingStyles) {
        this.formattingStore.addRange(
          createFormattingRange(type, editStart, insertEnd)
        );
      }
    }
    for (const type of pendingStyleRemovals) {
      this.formattingStore.removeType(type, editStart, insertEnd);
    }
  }
}
