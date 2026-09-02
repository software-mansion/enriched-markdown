import { BlockStore, paragraphBounds } from '../formatting/BlockStore';
import { FormattingStore } from '../formatting/FormattingStore';
import { parseToPlainTextAndRanges } from '../formatting/InputParser';
import type { RangeBounds } from '../model/rangeBounds';
import { DomRenderer } from '../render/DomRenderer';
import { projectParagraphs } from '../render/InputProjection';
import { ENRM_INPUT_CLASS, injectInputStyles } from '../render/inputStyles';
import { LIST_ITEM_BLOCK_TYPES } from '../model/blocks';
import { EditPipeline } from './EditPipeline';
import { EditSession } from './EditSession';
import { SelectionMapper } from './SelectionMapper';
import { charLengthBefore, charLengthAfter } from '../utils';

export interface InputHostCallbacks {
  onChangeText?: (text: string) => void;
  onChangeSelection?: (selection: RangeBounds) => void;
}

export class InputHost {
  private readonly root: HTMLElement;
  private readonly callbacks: InputHostCallbacks;
  private readonly formattingStore = new FormattingStore();
  private readonly blockStore = new BlockStore();
  private readonly session = new EditSession();
  private readonly pipeline: EditPipeline;
  private readonly renderer: DomRenderer;
  private readonly mapper: SelectionMapper;

  private text = '';
  private selection: RangeBounds = { start: 0, end: 0 };

  constructor(root: HTMLElement, callbacks: InputHostCallbacks = {}) {
    this.root = root;
    this.callbacks = callbacks;
    this.pipeline = new EditPipeline(this.formattingStore, this.blockStore);
    this.renderer = new DomRenderer(root);
    this.mapper = new SelectionMapper(root, () => this.renderer.paragraphs);

    injectInputStyles();
    root.classList.add(ENRM_INPUT_CLASS);
    root.contentEditable = 'true';
    root.setAttribute('role', 'textbox');
    root.setAttribute('aria-multiline', 'true');
    root.setAttribute('spellcheck', 'false');
    root.setAttribute('data-gramm', 'false');
    root.setAttribute('translate', 'no');

    root.addEventListener('beforeinput', this.handleBeforeInput);
    root.addEventListener('compositionstart', this.handleCompositionStart);
    root.addEventListener('compositionend', this.handleCompositionEnd);
    root.ownerDocument.addEventListener(
      'selectionchange',
      this.handleSelectionChange
    );

    this.render();
  }

  destroy(): void {
    this.root.removeEventListener('beforeinput', this.handleBeforeInput);
    this.root.removeEventListener(
      'compositionstart',
      this.handleCompositionStart
    );
    this.root.removeEventListener('compositionend', this.handleCompositionEnd);
    this.root.ownerDocument.removeEventListener(
      'selectionchange',
      this.handleSelectionChange
    );
  }

  get value(): string {
    return this.text;
  }

  async setValue(markdown: string): Promise<void> {
    const { plainText, formattingRanges, blockRanges } =
      await parseToPlainTextAndRanges(markdown);

    this.session.scoped('importing', () => {
      this.text = plainText;
      this.formattingStore.setRanges(formattingRanges);
      this.blockStore.setRanges(blockRanges);
      this.selection = { start: plainText.length, end: plainText.length };
    });
    this.render();
    this.emitChanges();
  }

  private readonly handleBeforeInput = (event: InputEvent): void => {
    // During composition the browser owns the DOM; the read-back step will
    // reconcile it later.
    if (this.session.isComposing) {
      return;
    }
    // Default-deny: unhandled input types become no-ops, never native edits.
    event.preventDefault();
    this.syncSelectionFromDom();

    switch (event.inputType) {
      case 'insertText':
        this.replaceSelection(event.data ?? '');
        break;
      case 'insertParagraph':
      case 'insertLineBreak':
        this.insertNewline();
        break;
      case 'deleteContentBackward':
        this.deleteBackward();
        break;
      case 'deleteContentForward':
        this.deleteForward();
        break;
      default:
        break;
    }
  };

  private syncSelectionFromDom(): void {
    const domSelection = this.root.ownerDocument.getSelection();
    if (domSelection === null) {
      return;
    }
    const mapped = this.mapper.modelSelectionFromDom(domSelection);
    if (mapped !== null) {
      this.selection = mapped;
    }
  }

  private readonly handleCompositionStart = (): void => {
    this.session.isComposing = true;
  };

  private readonly handleCompositionEnd = (): void => {
    this.session.isComposing = false;
  };

  private readonly handleSelectionChange = (): void => {
    if (
      this.session.shouldSuppressSelectionSideEffects ||
      this.session.isComposing
    ) {
      return;
    }
    const domSelection = this.root.ownerDocument.getSelection();
    if (domSelection === null) {
      return;
    }
    const mapped = this.mapper.modelSelectionFromDom(domSelection);
    if (mapped === null) {
      return;
    }
    if (
      mapped.start === this.selection.start &&
      mapped.end === this.selection.end
    ) {
      return;
    }
    this.selection = mapped;
    this.callbacks.onChangeSelection?.(mapped);
  };

  private insertNewline(): void {
    const { start, end } = this.selection;
    if (start === end && this.unlistEmptyListItem(start)) {
      return;
    }
    this.replaceSelection('\n');
  }

  private unlistEmptyListItem(caret: number): boolean {
    const line = paragraphBounds(caret, caret, this.text);
    if (line.start !== line.end) {
      return false;
    }
    const block = this.blockStore.blockStartingAt(line.start);
    if (block === null || !LIST_ITEM_BLOCK_TYPES.has(block.type)) {
      return false;
    }
    this.session.scoped('processing', () => {
      this.blockStore.removeBlock(line.start, line.start, this.text);
      this.blockStore.normalizeToLineBounds(this.text);
    });
    this.render();
    return true;
  }

  private replaceSelection(insertedText: string): void {
    const { start, end } = this.selection;
    this.applyEdit(start, this.text.slice(start, end), insertedText);
  }

  private deleteBackward(): void {
    const { start, end } = this.selection;
    if (start !== end) {
      this.replaceSelection('');
      return;
    }
    if (start === 0) {
      return;
    }
    const deleteFrom = start - charLengthBefore(this.text, start);
    this.applyEdit(deleteFrom, this.text.slice(deleteFrom, start), '');
  }

  private deleteForward(): void {
    const { start, end } = this.selection;
    if (start !== end) {
      this.replaceSelection('');
      return;
    }
    if (end >= this.text.length) {
      return;
    }
    const deleteTo = end + charLengthAfter(this.text, end);
    this.applyEdit(end, this.text.slice(end, deleteTo), '');
  }

  // The native keystroke choreography: model phase, render phase, then
  // events, in the iOS order.
  private applyEdit(
    editStart: number,
    deletedText: string,
    insertedText: string
  ): void {
    this.session.scoped('processing', () => {
      this.text =
        this.text.slice(0, editStart) +
        insertedText +
        this.text.slice(editStart + deletedText.length);
      this.pipeline.processTextChange(this.text, {
        editStart,
        deletedText,
        insertedText,
        pendingStyles: [],
        pendingStyleRemovals: [],
      });
      const caret = editStart + insertedText.length;
      this.selection = { start: caret, end: caret };
      this.session.recordTextChange();
    });
    this.render();
    this.emitChanges();
  }

  private render(): void {
    this.session.scoped('formatting', () => {
      this.renderer.render(
        this.text,
        projectParagraphs(
          this.text,
          this.formattingStore.allRanges,
          this.blockStore.allRanges
        )
      );
      this.writeSelectionToDom();
    });
  }

  private writeSelectionToDom(): void {
    const document = this.root.ownerDocument;
    if (!this.root.contains(document.activeElement)) {
      return;
    }
    const domSelection = document.getSelection();
    if (domSelection === null) {
      return;
    }
    // Compare in model offsets: a boundary caret has two DOM addresses, so
    // node identity would report false divergence on every render.
    const current = this.mapper.modelSelectionFromDom(domSelection);
    if (
      current !== null &&
      current.start === this.selection.start &&
      current.end === this.selection.end
    ) {
      return;
    }
    const start = this.mapper.domPositionFromModelOffset(this.selection.start);
    const end =
      this.selection.start === this.selection.end
        ? start
        : this.mapper.domPositionFromModelOffset(this.selection.end);
    if (start === null || end === null) {
      return;
    }
    domSelection.setBaseAndExtent(
      start.node,
      start.offset,
      end.node,
      end.offset
    );
  }

  private emitChanges(): void {
    if (this.session.shouldSuppressEvents) {
      return;
    }
    this.callbacks.onChangeText?.(this.text);
    this.callbacks.onChangeSelection?.(this.selection);
  }
}
