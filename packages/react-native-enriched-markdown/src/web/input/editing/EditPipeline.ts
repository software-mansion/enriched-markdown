import type { BlockStore } from '../formatting/BlockStore';
import type { FormattingStore } from '../formatting/FormattingStore';
import {
  createFormattingRange,
  type PendingStyleType,
} from '../model/inlineStyles';

export interface EditContext {
  editStart: number;
  deletedText: string;
  insertedText: string;
  pendingStyles: readonly PendingStyleType[];
  pendingStyleRemovals: readonly PendingStyleType[];
}

const LOG_PREFIX = '[EnrichedMarkdown - EditPipeline]';

export class EditPipeline {
  private readonly formattingStore: FormattingStore;
  private readonly blockStore: BlockStore;

  constructor(formattingStore: FormattingStore, blockStore: BlockStore) {
    this.formattingStore = formattingStore;
    this.blockStore = blockStore;
  }

  // Walks both stores through one text edit. `text` is the buffer after the
  // edit and `context` describes that same edit; the caller must splice one
  // to match the other before calling (checked in development only - see
  // `assertContextDescribesEdit`).
  processTextChange(text: string, context: EditContext): void {
    const { editStart, deletedText, insertedText } = context;

    if (__DEV__) {
      assertContextDescribesEdit(text, context);
    }

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
    // Deletions only, unlike the natives, which prune unconditionally. Their
    // block ranges grow at the start on insert (`growsAtStartOnInsert`), so an
    // anchor never leaves the line start by typing. Web deliberately lets it
    // shift and relies on `normalizeToLineBounds` to snap it back over the
    // typed characters (see `BlockStore.adjustForEdit`), so pruning on insert
    // would delete the block on every keystroke at a line start.
    if (deletedText.length > 0) {
      this.blockStore.pruneOrphanedAnchors(text);
    }
    this.blockStore.normalizeToLineBounds(text);

    if (insertedText.length > 0) {
      this.applyPendingStyles(context);
    }
  }

  private applyPendingStyles(context: EditContext): void {
    const { editStart, insertedText, pendingStyles, pendingStyleRemovals } =
      context;
    const insertEnd = editStart + insertedText.length;

    // Pending styles stop at the first newline in the insert. A range over a
    // bare newline corrupts `isStyleActive` at the line boundary, which is why
    // both natives skip a newline-only insertion; clipping rather than
    // skipping also keeps a multi-unit insert - paste, dictation, autocorrect
    // - from carrying a caret-level style onto the lines after the first.
    const firstNewline = insertedText.indexOf('\n');
    const styledEnd =
      firstNewline === -1 ? insertEnd : editStart + firstNewline;
    if (styledEnd > editStart) {
      for (const type of pendingStyles) {
        this.formattingStore.addRange(
          createFormattingRange(type, editStart, styledEnd)
        );
      }
    }
    // Removals cover the whole insert, newlines included: the new text must
    // not inherit a style from either side of the edit.
    for (const type of pendingStyleRemovals) {
      this.formattingStore.removeType(type, editStart, insertEnd);
    }
  }
}

// `text` and `context` describe the same edit twice and both stores trust
// both. A caller that splices one without the other stamps ranges over a
// buffer that no longer matches - the symptom surfaces much later as a wrong
// caret or a lost style, never as an error here, so say so while there is
// still a stack to say it on.
function assertContextDescribesEdit(text: string, context: EditContext): void {
  const { editStart, insertedText } = context;
  const insertEnd = editStart + insertedText.length;
  if (editStart < 0 || insertEnd > text.length) {
    console.error(
      `${LOG_PREFIX} invariant violated: insert [${editStart}, ${insertEnd}) falls outside the ${text.length}-unit buffer`
    );
    return;
  }
  if (text.slice(editStart, insertEnd) !== insertedText) {
    console.error(
      `${LOG_PREFIX} invariant violated: the buffer does not hold \`insertedText\` at ${editStart}`
    );
  }
}
