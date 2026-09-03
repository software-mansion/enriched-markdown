import { lineAtPosition, type BlockStore } from '../formatting/BlockStore';
import type { FormattingStore } from '../formatting/FormattingStore';
import { isListItem } from '../model/blocks';
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
    // Continuation must precede normalization: the new anchor keeps the
    // line chain adjacent, or the depth clamp would flatten nested items
    // that follow the fresh empty line.
    if (insertedText === '\n') {
      this.continueBlockOnNewline(text, editStart);
    }
    this.blockStore.normalizeToLineBounds(text);

    if (insertedText.length > 0) {
      this.applyPendingStyles(context);
    }

    return deletedText.includes('\n') || insertedText.includes('\n');
  }

  // Enter inside a list item continues the list on the new line; other
  // blocks do not continue.
  private continueBlockOnNewline(text: string, newlinePosition: number): void {
    // The inserted newline closes the line before it; take that line's block.
    const closedLine = lineAtPosition(newlinePosition, text);
    const closedBlock = this.blockStore.blockStartingAt(closedLine.start);
    if (!isListItem(closedBlock)) {
      return;
    }
    const { type, level } = closedBlock;
    const lineStart = closedLine.start;
    const freshLineStart = newlinePosition + 1;
    this.blockStore.setBlock(type, level, lineStart, lineStart, text);
    this.blockStore.setBlock(type, level, freshLineStart, freshLineStart, text);
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
