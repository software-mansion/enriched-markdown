import { BlockStore, lineAtPosition } from '../formatting/BlockStore';
import { FormattingStore } from '../formatting/FormattingStore';
import { parseToPlainTextAndRanges } from '../formatting/InputParser';
import { serialize } from '../formatting/MarkdownSerializer';
import type { RangeBounds } from '../model/rangeBounds';
import type { TextEdit } from '../model/textEdit';
import { DomRenderer } from '../render/DomRenderer';
import { computeStyleRuns, projectParagraphs } from '../render/InputProjection';
import { ENRM_INPUT_CLASS, injectInputStyles } from '../render/inputStyles';
import { isListItem, type BlockType } from '../model/blocks';
import type { PendingStyleType } from '../model/inlineStyles';
import { BlockEditCoordinator } from './BlockEditCoordinator';
import {
  EditHistory,
  type EditKind,
  type HistoryState,
  type ModelSnapshot,
} from './EditHistory';
import { EditPipeline } from './EditPipeline';
import { EditSession } from './EditSession';
import {
  nativeEditLanded,
  planNativeEdit,
  spansMatchRuns,
  type NativeEdit,
} from './NativeEdit';
import { isCaret, SelectionMapper, type DomPosition } from './SelectionMapper';
import { TypingAttributesController } from './TypingAttributesController';
import { buildInputState, sameInputState, type InputState } from './InputState';
import {
  clamp,
  codePointBoundaryAtOrBefore,
  graphemeLengthBefore,
  graphemeLengthAfter,
  isCodePointBoundary,
  isWhitespace,
} from '../utils';

export interface CaretRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface InputHostCallbacks {
  onChangeText?: (text: string) => void;
  onChangeSelection?: (selection: RangeBounds) => void;
  onChangeState?: (state: InputState) => void;
  onChangeMarkdown?: (markdown: string) => void;
  onChangeHistoryState?: (state: HistoryState) => void;
}

export interface InputHostOptions {
  // Left to the browser when unset, which is what native does too: the OS
  // keyboard spellchecks normally there. `false` turns it off, along with the
  // squiggles under anything markdown-ish.
  spellCheck?: boolean;
}

export class InputHost {
  private readonly root: HTMLElement;
  private readonly callbacks: InputHostCallbacks;
  private readonly formattingStore = new FormattingStore();
  private readonly blockStore = new BlockStore();
  private readonly session = new EditSession();
  private readonly history = new EditHistory();
  private readonly pipeline: EditPipeline;
  private readonly blockCoordinator: BlockEditCoordinator;
  private readonly typing: TypingAttributesController;
  private readonly renderer: DomRenderer;
  private readonly mapper: SelectionMapper;
  // Attributes this host set itself, and so the only ones it removes on
  // teardown: `role` and `aria-multiline` are set only when the node does not
  // already carry them, so a consumer's own value is never ours to undo.
  // `data-empty` is listed from the start because `render` toggles it rather
  // than setting it, and teardown has to clear it either way.
  private readonly ownedAttributes: string[] = ['data-empty'];

  private text = '';
  private selection: RangeBounds = { start: 0, end: 0 };
  // The DOM's anchor is `selection.end`.
  private selectionBackward = false;
  // Work that would write the DOM while an IME owns it - commands, imports,
  // imperative selection moves - waits here for the composition to end.
  private deferredUntilCompositionEnd: Array<() => void> = [];
  // A pointer drag is selecting. Links snap only once it ends (as on iOS);
  // rewriting the selection mid-drag fights the browser for its anchor.
  private pointerSelecting = false;
  // An edit the browser was left to perform (see `NativeEdit`), already in
  // the model and waiting for its `input` to be checked and rendered.
  private pendingNativeEdit: { edit: NativeEdit; runCount: number } | null =
    null;
  private destroyed = false;
  // Bumped by every import, so one still parsing can tell that a later import
  // has overtaken it. Only imports count: a user edit cannot race an import,
  // because the editor is inert while one is parsing.
  private importGeneration = 0;
  private pendingImports = 0;
  private editable = true;
  private markdownEmitEnabled = true;
  private lastEmittedMarkdown: string | null = null;
  private lastEmittedState: InputState | null = null;
  private lastEmittedHistory: HistoryState = { canUndo: false, canRedo: false };
  // WebKit raises one `historyUndo` per entry on its own stack for a single
  // Undo command once a scripted render has split that stack, so only the
  // first history input in a task is a step the user asked for.
  private historyInputPending = false;

  constructor(
    root: HTMLElement,
    callbacks: InputHostCallbacks = {},
    options: InputHostOptions = {}
  ) {
    this.root = root;
    this.callbacks = callbacks;
    this.pipeline = new EditPipeline(this.formattingStore, this.blockStore);
    this.blockCoordinator = new BlockEditCoordinator(this.blockStore);
    this.typing = new TypingAttributesController(this.formattingStore);
    this.renderer = new DomRenderer(root);
    this.mapper = new SelectionMapper(root, this.renderer);

    injectInputStyles();
    root.classList.add(ENRM_INPUT_CLASS);
    this.setOwnedAttribute('contenteditable', 'true');
    // A consumer may be passing these through as props; theirs wins.
    setAttributeIfAbsent(root, 'role', 'textbox');
    setAttributeIfAbsent(root, 'aria-multiline', 'true');
    if (options.spellCheck !== undefined) {
      root.setAttribute('spellcheck', String(options.spellCheck));
      this.ownedAttributes.push('spellcheck');
    }
    // Not configurable, unlike spellcheck: grammar and translation extensions
    // rewrite the text nodes under us, and nothing in this model can see that
    // happen.
    this.setOwnedAttribute('data-gramm', 'false');
    this.setOwnedAttribute('translate', 'no');

    root.addEventListener('beforeinput', this.handleBeforeInput);
    root.addEventListener('input', this.handleInput);
    root.addEventListener('keydown', this.handleKeyDown);
    root.addEventListener('pointerdown', this.handlePointerDown);
    root.addEventListener('compositionstart', this.handleCompositionStart);
    root.addEventListener('compositionend', this.handleCompositionEnd);
    root.addEventListener('focus', this.handleFocus);
    root.addEventListener('blur', this.handleBlur);
    root.addEventListener('cut', this.handleCut);
    root.addEventListener('paste', this.handlePaste);
    root.ownerDocument.addEventListener(
      'selectionchange',
      this.handleSelectionChange
    );
    root.ownerDocument.addEventListener('pointerup', this.handlePointerUp);
    root.ownerDocument.addEventListener('pointercancel', this.handlePointerUp);

    this.render();
  }

  destroy(): void {
    if (this.destroyed) {
      return;
    }
    this.destroyed = true;
    this.session.endComposition();
    this.pendingNativeEdit = null;
    // Deferred commands no-op once destroyed; a deferred `setValue` resolves
    // and returns false, so the import queue behind it does not stall.
    this.runDeferredCommands();

    this.root.removeEventListener('beforeinput', this.handleBeforeInput);
    this.root.removeEventListener('input', this.handleInput);
    this.root.removeEventListener('keydown', this.handleKeyDown);
    this.root.removeEventListener('pointerdown', this.handlePointerDown);
    this.root.removeEventListener(
      'compositionstart',
      this.handleCompositionStart
    );
    this.root.removeEventListener('compositionend', this.handleCompositionEnd);
    this.root.removeEventListener('focus', this.handleFocus);
    this.root.removeEventListener('blur', this.handleBlur);
    this.root.removeEventListener('cut', this.handleCut);
    this.root.removeEventListener('paste', this.handlePaste);
    this.root.ownerDocument.removeEventListener(
      'selectionchange',
      this.handleSelectionChange
    );
    this.root.ownerDocument.removeEventListener(
      'pointerup',
      this.handlePointerUp
    );
    this.root.ownerDocument.removeEventListener(
      'pointercancel',
      this.handlePointerUp
    );

    // Leave nothing editable behind. A consumer that owns the node and keeps
    // it would otherwise hand the user a contentEditable with no model
    // underneath, which accepts typing and reports none of it.
    for (const attribute of this.ownedAttributes) {
      this.root.removeAttribute(attribute);
    }
    this.root.classList.remove(ENRM_INPUT_CLASS);
    this.root.replaceChildren();
  }

  get value(): string {
    return this.text;
  }

  getMarkdown(): string {
    return serialize(
      this.text,
      this.formattingStore.allRanges,
      this.blockStore.allRanges
    );
  }

  // The prop path (`defaultValue` and friends): loads the markdown without
  // reporting it back, because the app already has this value. Matches
  // Android, which holds its importing phase across the whole import, and
  // iOS, whose `importMarkdown` emits nothing.
  async importValue(markdown: string): Promise<void> {
    await this.loadValue(markdown);
  }

  focus(): void {
    this.root.focus();
  }

  // Writes the attribute rather than the `contentEditable` IDL property, which
  // is how the constructor sets it in the first place - so the node's
  // editability reads the same whether it was set at construction or flipped
  // later. The name is already registered as ours, so teardown clears it.
  setEditable(editable: boolean): void {
    this.editable = editable;
    this.root.setAttribute('contenteditable', editable ? 'true' : 'false');
  }

  // Mirrors native's `isOnChangeMarkdownSet` prop. Every edit would otherwise
  // serialize the whole document, and a wrapper that forwards the event
  // through a stable closure cannot be told apart from a real listener by
  // inspecting the callback.
  setMarkdownEmitEnabled(enabled: boolean): void {
    this.markdownEmitEnabled = enabled;
    // Whatever was emitted before the gap says nothing about what the
    // listener last saw.
    this.lastEmittedMarkdown = null;
  }

  // In the root's content coordinates (padding box plus scroll offset), as
  // the natives report it. Reads the DOM caret, since the model selection
  // trails it until the queued `selectionchange` fires.
  caretRect(): CaretRect | null {
    const domSelection = this.readDomSelection();
    const offset = domSelection?.selection.start ?? this.selection.start;
    const box = this.caretBoxAtOffset(offset);
    if (box === null) {
      return null;
    }
    const rootRect = this.root.getBoundingClientRect();
    return {
      x: box.left - rootRect.left - this.root.clientLeft + this.root.scrollLeft,
      y: box.top - rootRect.top - this.root.clientTop + this.root.scrollTop,
      // Nothing laid out (a detached editor) has no caret to give a width.
      width: isZeroBox(box) ? 0 : caretWidth(this.root.ownerDocument),
      height: box.height,
    };
  }

  // The caret's box in viewport coordinates; all zeros where nothing is laid
  // out.
  private caretBoxAtOffset(offset: number): CaretBox | null {
    const position = this.mapper.domPositionFromModelOffset(offset);
    if (position === null) {
      return null;
    }
    return caretBoxAt(this.root.ownerDocument, position);
  }

  blur(): void {
    this.root.blur();
  }

  // The imperative command path: loads the markdown and then reports it, the
  // way iOS's `setValue:` command re-emits once the import returns. Keeping
  // the two apart matters at the wrapper, where one `setValue` serving both
  // would make mounting with a `defaultValue` fire `onChangeText` with the
  // value the app just supplied.
  async setValue(markdown: string): Promise<void> {
    if (await this.loadValue(markdown)) {
      this.emitTextEdited();
    }
  }

  // Returns whether the import was applied: a second import started while
  // this one was parsing supersedes it, and so does teardown.
  private async loadValue(markdown: string): Promise<boolean> {
    const generation = ++this.importGeneration;
    // The parse is asynchronous, and the window it opens is the one that
    // needs covering: the phase below only wraps the synchronous model write,
    // which was never at risk. Holding the editor inert for the duration is
    // what native does (its import owns the whole body) and means a keystroke
    // cannot be silently overwritten by the value landing afterwards.
    this.pendingImports++;
    let parsed: Awaited<ReturnType<typeof parseToPlainTextAndRanges>>;
    try {
      parsed = await parseToPlainTextAndRanges(markdown);
    } finally {
      this.pendingImports--;
    }
    if (this.destroyed || generation !== this.importGeneration) {
      return false;
    }
    // Rewriting every node under a running IME would hand its leftovers to a
    // read-back that diffs them against the new model.
    if (this.session.isComposing) {
      await new Promise<void>((resolve) =>
        this.deferredUntilCompositionEnd.push(resolve)
      );
      if (this.destroyed || generation !== this.importGeneration) {
        return false;
      }
    }

    const { plainText, formattingRanges, blockRanges } = parsed;
    this.settleNativeEdit();
    this.session.scoped('importing', () => {
      this.text = plainText;
      this.formattingStore.setRanges(formattingRanges);
      this.blockStore.setRanges(blockRanges);
      this.selection = { start: plainText.length, end: plainText.length };
      this.selectionBackward = false;
      // A new value is a new document, as native's `setText` makes it.
      this.history.clear();
    });
    this.render();
    this.emitHistoryState();
    return true;
  }

  // Clamps the way iOS does - into the buffer, then `end` up to `start`, so a
  // reversed range collapses rather than flipping - and additionally snaps off
  // the seam inside a surrogate pair, which UIKit does for us there but which
  // nothing here would catch before the next edit split the pair.
  // Links are atomic, as on both natives.
  setSelection(start: number, end: number): void {
    this.settleNativeEdit();
    if (this.deferWhileComposing(() => this.setSelection(start, end))) {
      return;
    }
    const max = this.text.length;
    const clampedStart = clamp(start, 0, max);
    const snapped = {
      start: codePointBoundaryAtOrBefore(this.text, clampedStart),
      end: codePointBoundaryAtOrBefore(
        this.text,
        clamp(end, clampedStart, max)
      ),
    };
    this.selection =
      this.formattingStore.selectionAdjustedForAtomicLinks(
        snapped.start,
        snapped.end
      ) ?? snapped;
    this.selectionBackward = false;
    // Nothing in the model changed, so there is nothing to render; only the
    // DOM selection moves.
    this.session.scoped('formatting', () => this.writeSelectionToDom());
    this.resetTypingAfterSelectionMove();
    this.emitSelectionMoved();
  }

  indentList(): void {
    this.command(() => this.changeListDepthBy(1));
  }

  outdentList(): void {
    this.command(() => this.changeListDepthBy(-1));
  }

  toggleUnorderedList(): void {
    this.command(() => this.toggleListType('unordered-list-item'));
  }

  toggleOrderedList(): void {
    this.command(() => this.toggleListType('ordered-list-item'));
  }

  toggleBold(): void {
    this.toggleInlineStyle('strong');
  }

  toggleItalic(): void {
    this.toggleInlineStyle('em');
  }

  toggleUnderline(): void {
    this.toggleInlineStyle('underline');
  }

  toggleStrikethrough(): void {
    this.toggleInlineStyle('strikethrough');
  }

  toggleSpoiler(): void {
    this.toggleInlineStyle('spoiler');
  }

  toggleHeading(level: number): void {
    this.command(() => {
      this.recordFormatting();
      const changed = this.session.scoped('processing', () =>
        this.blockCoordinator.toggleHeading(level, this.selection, this.text)
      );
      if (!changed) {
        this.history.discardFormatting();
        return;
      }
      this.render();
      this.emitFormattingChanged();
    });
  }

  undo(): void {
    this.command(() => {
      const step = this.history.undo(this.captureSnapshot);
      if (step !== null) {
        this.restore(step.edits, 'undo', step.target);
      }
    });
  }

  redo(): void {
    this.command(() => {
      const step = this.history.redo();
      if (step !== null) {
        this.restore(step.edits, 'redo', step.target);
      }
    });
  }

  // Mid-composition a command would rewrite the nodes under the IME, so it
  // waits for the composition to end.
  private command(run: () => void): void {
    this.settleNativeEdit();
    if (!this.deferWhileComposing(run)) {
      run();
    }
  }

  private deferWhileComposing(run: () => void): boolean {
    if (!this.session.isComposing) {
      return false;
    }
    this.deferredUntilCompositionEnd.push(() => {
      if (!this.destroyed) {
        run();
      }
    });
    return true;
  }

  private runDeferredCommands(): void {
    const deferred = this.deferredUntilCompositionEnd;
    this.deferredUntilCompositionEnd = [];
    for (const run of deferred) {
      if (this.session.isComposing) {
        // A new composition began from inside one of them; the rest wait.
        this.deferredUntilCompositionEnd.push(run);
        continue;
      }
      run();
    }
  }

  private readonly handleBeforeInput = (event: InputEvent): void => {
    if (!this.editable) {
      event.preventDefault();
      return;
    }
    // The browser owns the DOM during a composition and `beforeinput` for
    // `insertCompositionText` is not cancelable in every engine, so the model
    // stays out of the way and reads the result back on `compositionend`.
    if (event.isComposing || this.session.isComposing) {
      return;
    }
    this.settleNativeEdit();
    // An import is parsing: the value the app asked for is about to replace
    // everything, so an edit now would be overwritten anyway.
    if (this.pendingImports === 0 && this.letBrowserEdit(event)) {
      return;
    }
    // Default-deny: unhandled input types become no-ops, never native edits.
    event.preventDefault();
    if (this.pendingImports > 0) {
      return;
    }
    this.syncSelectionFromDom();

    switch (event.inputType) {
      // Corrections address their own word, and Safari can send either type.
      case 'insertText':
      case 'insertReplacementText':
        this.replaceTargetRange(event, insertedTextOf(event));
        break;
      // The model owns history, whoever wrote the DOM: the browser's own
      // stack holds the native-edit fast path's keystrokes and nothing else,
      // so replaying it would drift from the model.
      case 'historyUndo':
      case 'historyRedo':
        this.historyInput(event.inputType);
        break;
      case 'insertParagraph':
      case 'insertLineBreak':
        this.insertNewline();
        break;
      // Deletes prefer the platform's target range: word and visual-line
      // bounds depend on locale and layout. The scanners are the fallback.
      case 'deleteContentBackward':
        this.deleteBackwardTo(
          event,
          this.selection.start -
            graphemeLengthBefore(this.text, this.selection.start),
          'deleting'
        );
        break;
      case 'deleteContentForward':
        this.deleteForwardTo(
          event,
          this.selection.end +
            graphemeLengthAfter(this.text, this.selection.end),
          'deleting'
        );
        break;
      case 'deleteWordBackward':
        this.deleteBackwardTo(
          event,
          wordStartBefore(this.text, this.selection.start)
        );
        break;
      case 'deleteWordForward':
        this.deleteForwardTo(
          event,
          wordEndAfter(this.text, this.selection.end)
        );
        break;
      case 'deleteSoftLineBackward':
      case 'deleteHardLineBackward':
        this.deleteBackwardTo(
          event,
          lineStartBefore(this.text, this.selection.start)
        );
        break;
      case 'deleteSoftLineForward':
      case 'deleteHardLineForward':
        this.deleteForwardTo(
          event,
          lineEndAfter(this.text, this.selection.end)
        );
        break;
      // `deleteByCut` is the second half of a cut, which `handleCut` has
      // already performed; `insertFromPaste` likewise belongs to
      // `handlePaste`. Cancelling them here is what keeps the browser from
      // doing it a second time.
      //
      // Still deliberately denied, with nothing behind them yet:
      // - `insertParagraph` / `insertLineBreak`: Enter, which has to continue
      //   lists and split blocks. Lands with the formatting commands.
      // - `formatBold` and friends: the commands own these, including the
      //   keyboard shortcuts that raise them.
      // - `insertFromDrop`: needs a caret-from-point mapping to know where the
      //   drop landed. Denying it is inert rather than wrong.
      default:
        break;
    }
  };

  private historyInput(inputType: 'historyUndo' | 'historyRedo'): void {
    if (this.historyInputPending) {
      return;
    }
    this.historyInputPending = true;
    setTimeout(() => {
      this.historyInputPending = false;
    }, 0);
    if (inputType === 'historyUndo') {
      this.undo();
    } else {
      this.redo();
    }
  }

  // Applies the edit to the model and lets the browser write the DOM when
  // that matches what a render would (see `NativeEdit`). False when the edit
  // is not a candidate; a candidate whose runs differ is cancelled and
  // rendered here.
  private letBrowserEdit(event: InputEvent): boolean {
    if (this.renderer.hasDirtyLines) {
      return false;
    }
    const edit = planNativeEdit(event, {
      root: this.root,
      isLine: this.isRenderedLine,
      modelOffsetFromDom: (node, offset) =>
        this.mapper.modelOffsetFromDom(node, offset),
    });
    if (edit === null) {
      return false;
    }
    const { editStart, deletedText, insertedText } = edit;
    // A Backspace into a link deletes all of it, which is the model's edit
    // to make.
    if (
      deletedText.length > 0 &&
      this.formattingStore.isStyleActiveInRange(
        'link',
        editStart,
        editStart + deletedText.length
      )
    ) {
      return false;
    }
    this.syncSelectionFromDom();
    this.applyModelEdit(edit, insertedText.length > 0 ? 'typing' : 'deleting');
    const line = lineAtPosition(editStart, this.text);
    const runs = computeStyleRuns(
      this.formattingStore.allRanges,
      line.start,
      line.end
    );
    if (!spansMatchRuns(edit, runs, this.text)) {
      event.preventDefault();
      this.renderEdit();
      return true;
    }
    this.pendingNativeEdit = { edit, runCount: runs.length };
    // `input` follows within the same task; the timer is for an engine that
    // lets the event through and then performs nothing.
    setTimeout(() => this.settleNativeEdit(), 0);
    return true;
  }

  // Once the browser has made a native edit: a no-op render if it landed as
  // planned, otherwise its line is rewritten from the model.
  private settleNativeEdit(): void {
    const pending = this.pendingNativeEdit;
    if (pending === null || this.destroyed) {
      return;
    }
    this.pendingNativeEdit = null;
    if (
      !nativeEditLanded(pending.edit, this.isRenderedLine, pending.runCount)
    ) {
      const index = this.renderer.indexOfLine(pending.edit.line);
      if (index === -1) {
        this.renderer.invalidate();
      } else {
        this.renderer.markLinesDirty(index, index);
      }
    }
    this.render();
    this.emitTextEdited();
  }

  private readonly isRenderedLine = (node: Node): boolean =>
    this.renderer.indexOfLine(node) !== -1;

  private syncSelectionFromDom(): void {
    const mapped = this.readDomSelection();
    if (mapped !== null) {
      this.selection = mapped.selection;
      this.selectionBackward = mapped.backward;
    }
  }

  // The DOM selection in model offsets, snapped off surrogate seams like
  // `setSelection`'s arguments.
  private readDomSelection(): {
    selection: RangeBounds;
    backward: boolean;
  } | null {
    const domSelection = this.root.ownerDocument.getSelection();
    if (domSelection === null) {
      return null;
    }
    const points = this.mapper.modelSelectionFromDom(domSelection);
    if (points === null) {
      return null;
    }
    const anchor = this.snapToModel(points.anchor);
    const focus = this.snapToModel(points.focus);
    return {
      selection: {
        start: Math.min(anchor, focus),
        end: Math.max(anchor, focus),
      },
      backward: focus < anchor,
    };
  }

  private snapToModel(offset: number): number {
    return codePointBoundaryAtOrBefore(
      this.text,
      clamp(offset, 0, this.text.length)
    );
  }

  // Tab never reaches beforeinput (the browser moves focus). The history
  // shortcuts do as `historyUndo`/`historyRedo`, but not cancelably in every
  // engine, so they are taken here before the browser undoes anything itself.
  private readonly handleKeyDown = (event: KeyboardEvent): void => {
    if (!this.editable || event.isComposing || this.session.isComposing) {
      return;
    }
    if (event.key === 'Tab') {
      event.preventDefault();
      this.settleNativeEdit();
      this.syncSelectionFromDom();
      if (event.shiftKey) {
        this.outdentList();
      } else {
        this.indentList();
      }
      return;
    }
    const shortcut = historyShortcut(
      event,
      this.root.ownerDocument.defaultView?.navigator ?? null
    );
    if (shortcut === null) {
      return;
    }
    event.preventDefault();
    if (this.pendingImports > 0) {
      return;
    }
    if (shortcut === 'undo') {
      this.undo();
    } else {
      this.redo();
    }
  };

  private readonly handleCompositionStart = (): void => {
    this.settleNativeEdit();
    if (this.pendingImports === 0) {
      this.syncSelectionFromDom();
    }
    this.session.beginComposition();
    // A composition is an undo step of its own.
    this.history.breakGroup();
    // Rewrite the IME's lines when it ends, even if the text matches.
    this.renderer.markLinesDirty(
      this.mapper.lineIndexAt(this.selection.start),
      this.mapper.lineIndexAt(this.selection.end)
    );
    // The placeholder would draw over the composed text.
    this.root.toggleAttribute('data-empty', false);
  };

  private readonly handleCompositionEnd = (): void => {
    this.endComposition();
  };

  private endComposition(): void {
    this.session.endComposition();
    this.recoverComposition('composition');
    this.history.breakGroup();
    this.runDeferredCommands();
  }

  // `input` only reports DOM changes the browser made itself:
  // - a native edit, settled here;
  // - a composition update, followed in the model without rendering so
  //   `value` and `getMarkdown` include the word still being composed (Chrome
  //   Android composes until a space), as Android native does;
  // - an edit that escaped `preventDefault` (Android Chrome, non-cancelable
  //   types, `execCommand`, extensions), read back like a composition.
  private readonly handleInput = (event: Event): void => {
    if (this.destroyed) {
      return;
    }
    const composing =
      (event as InputEvent).isComposing || this.session.isComposing;
    if (!composing && this.pendingNativeEdit !== null) {
      this.settleNativeEdit();
      return;
    }
    if (composing) {
      if (this.editable && this.pendingImports === 0) {
        this.readBackFromDom({ render: false, kind: 'composition' });
      }
      return;
    }
    this.renderer.markLinesDirty(
      this.mapper.lineIndexAt(this.selection.start),
      this.mapper.lineIndexAt(this.selection.end)
    );
    if (this.pendingImports > 0) {
      // The import is about to replace everything; put the model back.
      this.renderer.invalidate();
      this.render();
      return;
    }
    this.recoverComposition('other');
  };

  private readonly handlePointerDown = (event: PointerEvent): void => {
    this.pointerSelecting = event.isPrimary && event.button === 0;
  };

  private readonly handlePointerUp = (): void => {
    if (!this.pointerSelecting) {
      return;
    }
    this.pointerSelecting = false;
    // The gesture's last selection change came while it was still running
    // and was left unsnapped.
    this.handleSelectionChange();
  };

  private readonly handleFocus = (): void => {
    // The browser places its own caret when a contentEditable takes focus, and
    // `writeSelectionToDom` declines to write while the editor is unfocused.
    // Without this, a `setSelection` issued before the focus would be
    // overwritten by that caret the moment the focus arrived.
    if (this.destroyed) {
      return;
    }
    this.session.scoped('formatting', () => this.writeSelectionToDom());
  };

  private readonly handleBlur = (): void => {
    // A composition abandoned by a blur does not always fire
    // `compositionend`, and a latched composition flag makes the editor
    // read-only: every `beforeinput` short-circuits.
    if (this.session.isComposing) {
      this.endComposition();
    }
  };

  // A composition that ends on a read-only editor - `editable` was flipped
  // while the IME held the DOM - must not be read back as an edit, but the
  // nodes the IME left behind still have to go, so the model is rendered over
  // them instead.
  private recoverComposition(kind: EditKind): void {
    if (this.editable) {
      this.readBackFromDom({ kind });
      return;
    }
    this.renderer.invalidate();
    this.render();
  }

  private readonly handleCut = (event: ClipboardEvent): void => {
    // The UA writes the clipboard and then performs the deletion, whose
    // `beforeinput` arrives as `deleteByCut` and gets cancelled. Taking over
    // both halves is what stops a cut from copying the text and leaving it
    // in place. On a read-only editor both halves stay cancelled, the way
    // iOS and Android drop Cut from the menu and leave Copy, which is not
    // intercepted here at all.
    event.preventDefault();
    if (!this.editable || this.session.isComposing || this.pendingImports > 0) {
      return;
    }
    this.settleNativeEdit();
    this.syncSelectionFromDom();
    const { start, end } = this.selection;
    if (start === end) {
      return;
    }
    event.clipboardData?.setData('text/plain', this.text.slice(start, end));
    this.applyEdit({
      editStart: start,
      deletedText: this.text.slice(start, end),
      insertedText: '',
    });
  };

  private readonly handlePaste = (event: ClipboardEvent): void => {
    event.preventDefault();
    if (!this.editable || this.session.isComposing || this.pendingImports > 0) {
      return;
    }
    this.settleNativeEdit();
    // Plain text only. Pasting markdown as formatted content means running
    // the parser and merging an import into the middle of the buffer, which
    // is a separate concern from this shell.
    const pasted = event.clipboardData?.getData('text/plain') ?? '';
    if (pasted.length === 0) {
      return;
    }
    this.syncSelectionFromDom();
    this.replaceSelection(normalizeLineEndings(pasted));
  };

  private readonly handleSelectionChange = (): void => {
    // This guard only catches a side effect delivered on the same stack as
    // the write. `selectionchange` is queued on the user interaction task
    // source instead, so by delivery time the render's scope has exited and
    // the phase is back to idle. What actually swallows the echo of our own
    // render is the offset comparison at the end: the mapper's round trip is
    // lossless, so a caret we just restored maps back to the offset already
    // held. Do not drop it as redundant.
    if (
      this.session.shouldSuppressSelectionSideEffects ||
      this.session.isComposing ||
      this.destroyed
    ) {
      return;
    }
    // A render dirties any selection inside the nodes it rewrites (replacing a
    // text node's data collapses the live ranges within it), and
    // `writeSelectionToDom` only puts it back while the editor has focus.
    // Without this, that unrestored selection arrives here and reports a
    // change for a document the user never touched.
    if (!this.hasFocus()) {
      return;
    }
    this.settleNativeEdit();
    const domSelection = this.root.ownerDocument.getSelection();
    const read = this.readDomSelection();
    if (domSelection === null || read === null) {
      return;
    }
    // Links are atomic, as on both natives. A drag in progress is left alone;
    // `handlePointerUp` snaps it once it ends.
    const atomic = this.pointerSelecting
      ? null
      : this.formattingStore.selectionAdjustedForAtomicLinks(
          read.selection.start,
          read.selection.end
        );
    const mapped = atomic ?? read.selection;
    if (
      mapped.start === this.selection.start &&
      mapped.end === this.selection.end
    ) {
      this.selectionBackward = read.backward;
      // Compared in model offsets, not nodes: the echo of our own write
      // points into nodes a render replaced. An empty line maps a stretched
      // highlight to one offset (see `isCaret`), so the DOM may still need
      // the write.
      if (
        atomic !== null ||
        isCaret(domSelection) !== (mapped.start === mapped.end)
      ) {
        this.session.scoped('formatting', () => this.writeSelectionToDom());
      }
      return;
    }
    this.selection = mapped;
    this.selectionBackward = read.backward;
    if (atomic !== null) {
      this.session.scoped('formatting', () => this.writeSelectionToDom());
    }
    this.resetTypingAfterSelectionMove();
    this.emitSelectionMoved();
  };

  // Echoes of our own caret writes are swallowed by the offset comparison
  // above, so no grace window is needed (iOS keeps 100 ms).
  private resetTypingAfterSelectionMove(): void {
    this.typing.resetForSelectionChange(this.selection);
    // Typing somewhere else is a new undo step.
    this.history.breakGroup();
  }

  // The browser owns the DOM through a composition, so the composed text
  // lands without the model seeing it. This recovers it afterwards: read the
  // text back out of the rendered nodes, diff it against the model to get the
  // one edit the composition made, and run that edit through the ordinary
  // path.
  //
  // Without this the two diverge permanently - the composed text stays on
  // screen while `value` and `onChangeText` omit it, so the user saves and
  // their text is not there - and whatever nodes the IME left behind go on
  // confusing the selection mapping. The scope is wider than CJK: macOS dead
  // keys, iOS Safari autocorrect and GBoard suggestions all compose.
  //
  // The diff is anchored on the DOM caret (see `diffEdit`). `render: false`
  // is the mid-composition update, while the DOM still belongs to the IME.
  private readBackFromDom({
    render = true,
    kind,
  }: {
    render?: boolean;
    kind: EditKind;
  }): void {
    if (this.destroyed) {
      return;
    }
    const domSelection = this.root.ownerDocument.getSelection();
    const focus =
      domSelection?.focusNode != null &&
      this.root.contains(domSelection.focusNode)
        ? { node: domSelection.focusNode, offset: domSelection.focusOffset }
        : null;
    const { text: domText, caret } = readTextFromDom(this.root, focus);
    if (domText === this.text) {
      // The IME's lines were marked dirty, so this still rewrites them.
      if (render) {
        this.render();
      }
      return;
    }
    this.applyEdit(diffEdit(this.text, domText, caret), {
      caret: caret === null ? undefined : caret,
      render,
      kind,
    });
  }

  private insertNewline(): void {
    const { start, end } = this.selection;
    if (start === end && this.unlistEmptyListItem(start)) {
      return;
    }
    this.replaceSelection('\n');
  }

  private unlistEmptyListItem(caret: number): boolean {
    const line = lineAtPosition(caret, this.text);
    const block = this.blockStore.blockAt(caret, this.text);
    if (line.start !== line.end || !isListItem(block)) {
      return false;
    }
    this.toggleListType(block.type);
    return true;
  }

  // Backspace at the start of a list item outdents it, or un-lists it at
  // depth 0, instead of merging with the line above.
  private outdentListAtLineStart(caret: number): boolean {
    const line = lineAtPosition(caret, this.text);
    if (
      caret !== line.start ||
      !isListItem(this.blockStore.blockAt(caret, this.text))
    ) {
      return false;
    }
    this.outdentList();
    return true;
  }

  private changeListDepthBy(delta: number): void {
    this.recordFormatting();
    const changed = this.session.scoped('processing', () =>
      this.blockCoordinator.changeListDepthBy(delta, this.selection, this.text)
    );
    if (!changed) {
      this.history.discardFormatting();
    } else {
      this.render();
      this.emitFormattingChanged();
    }
  }

  private toggleListType(type: BlockType): void {
    // Also reached from Enter and Backspace, which never run mid-composition.
    this.recordFormatting();
    this.session.scoped('processing', () =>
      this.blockCoordinator.toggleListType(type, this.selection, this.text)
    );
    this.render();
    this.emitFormattingChanged();
  }

  private toggleInlineStyle(type: PendingStyleType): void {
    this.command(() => {
      const { start, end } = this.selection;
      // A caret toggle changes no store, so there is nothing to undo; what
      // is typed with it is a step of its own, though.
      if (start !== end) {
        this.recordFormatting();
      } else {
        this.history.breakGroup();
      }
      const wasActive = this.session.scoped('processing', () =>
        this.formattingStore.toggleStyle(type, start, end)
      );
      this.typing.toggleStyle(type, wasActive, start !== end);
      if (start === end) {
        // A caret toggle only pends a style for the next keystroke; the
        // stores, and so the DOM and the markdown, are unchanged.
        this.emitState();
        return;
      }
      this.render();
      this.emitFormattingChanged();
    });
  }

  // Empty text is a no-op even over a selection, as on the natives.
  insertText(text: string): void {
    if (text.length === 0) {
      return;
    }
    this.command(() => this.replaceSelection(text));
  }

  private replaceSelection(insertedText: string): void {
    const { start, end } = this.selection;
    this.applyEdit({
      editStart: start,
      deletedText: this.text.slice(start, end),
      insertedText,
    });
  }

  // The event's target range, or the selection when it has none.
  private replaceTargetRange(event: InputEvent, insertedText: string): void {
    const target = this.modelRangeFromTargetRanges(event) ?? this.selection;
    if (insertedText.length === 0 && target.start === target.end) {
      return;
    }
    const deletedText = this.text.slice(target.start, target.end);
    this.applyEdit(
      { editStart: target.start, deletedText, insertedText },
      {
        kind:
          deletedText.length === 0 && !insertedText.includes('\n')
            ? 'typing'
            : 'other',
      }
    );
  }

  // The range an input type carries on the event rather than in the selection.
  private modelRangeFromTargetRanges(event: InputEvent): RangeBounds | null {
    if (typeof event.getTargetRanges !== 'function') {
      return null;
    }
    const [target] = event.getTargetRanges();
    if (target === undefined) {
      return null;
    }
    const start = this.mapper.modelOffsetFromDom(
      target.startContainer,
      target.startOffset
    );
    const end = this.mapper.modelOffsetFromDom(
      target.endContainer,
      target.endOffset
    );
    if (start === null || end === null) {
      return null;
    }
    const from = this.snapToModel(Math.min(start, end));
    const to = this.snapToModel(Math.max(start, end));
    return { start: from, end: to };
  }

  // Deletes back to the event's target range, else to `fallback`. A fallback
  // that makes no progress (caret at a line start) deletes the newline.
  // `kind` is `deleting` for a single character, so a run of them is one
  // undo step.
  private deleteBackwardTo(
    event: InputEvent,
    fallback: number,
    kind: EditKind = 'other'
  ): void {
    const { start, end } = this.selection;
    if (start !== end) {
      this.replaceSelection('');
      return;
    }
    if (this.outdentListAtLineStart(start) || start === 0) {
      return;
    }
    if (this.deleteLinkBefore(start)) {
      return;
    }
    const target = this.modelRangeFromTargetRanges(event);
    if (target !== null && target.start < target.end) {
      this.deleteRange(target, kind);
      return;
    }
    const from =
      fallback < start
        ? fallback
        : start - graphemeLengthBefore(this.text, start);
    this.deleteRange({ start: from, end: start }, kind);
  }

  private deleteForwardTo(
    event: InputEvent,
    fallback: number,
    kind: EditKind = 'other'
  ): void {
    const { start, end } = this.selection;
    if (start !== end) {
      this.replaceSelection('');
      return;
    }
    if (end >= this.text.length) {
      return;
    }
    const target = this.modelRangeFromTargetRanges(event);
    if (target !== null && target.start < target.end) {
      this.deleteRange(target, kind);
      return;
    }
    const to =
      fallback > end ? fallback : end + graphemeLengthAfter(this.text, end);
    this.deleteRange({ start: end, end: to }, kind);
  }

  private deleteRange(
    { start, end }: RangeBounds,
    kind: EditKind = 'other'
  ): void {
    this.applyEdit(
      {
        editStart: start,
        deletedText: this.text.slice(start, end),
        insertedText: '',
      },
      { kind }
    );
  }

  // Backspace into a link deletes all of it, as on both natives.
  private deleteLinkBefore(caret: number): boolean {
    const link = this.formattingStore.rangeOfType('link', caret - 1);
    if (link === null) {
      return false;
    }
    this.deleteRange(link);
    return true;
  }

  // The native keystroke choreography: model phase, render phase, then
  // events, in the iOS order.
  // `caret` overrides where the caret lands; `render: false` leaves the DOM
  // to the IME. `kind` decides whether the edit joins the open undo step.
  private applyEdit(
    edit: TextEdit,
    {
      caret,
      render = true,
      kind = 'other',
    }: { caret?: number; render?: boolean; kind?: EditKind } = {}
  ): void {
    this.applyModelEdit(edit, kind, caret);
    if (render) {
      this.renderEdit();
    } else {
      this.emitTextEdited();
    }
  }

  private renderEdit(): void {
    this.render();
    this.scrollCaretIntoView();
    this.emitTextEdited();
  }

  // Text, stores and caret only; no DOM, no events. The one place text
  // changes, and so the one place it is recorded.
  private applyModelEdit(edit: TextEdit, kind: EditKind, caret?: number): void {
    const { editStart, deletedText, insertedText } = edit;
    const text =
      this.text.slice(0, editStart) +
      insertedText +
      this.text.slice(editStart + deletedText.length);
    const landing = codePointBoundaryAtOrBefore(
      text,
      clamp(caret ?? editStart + insertedText.length, 0, text.length)
    );
    this.history.record(edit, kind, this.captureSnapshot, landing);
    this.session.scoped('processing', () => {
      this.text = text;
      this.pipeline.processTextChange(this.text, {
        editStart,
        deletedText,
        insertedText,
        pendingStyles: this.typing.styles,
        pendingStyleRemovals: this.typing.styleRemovals,
      });
      this.selection = { start: landing, end: landing };
      this.selectionBackward = false;
    });
  }

  // The history packs what it keeps, so the live ranges are handed over as
  // they are.
  private readonly captureSnapshot = (): ModelSnapshot => ({
    formatting: this.formattingStore.allRanges,
    blocks: this.blockStore.allRanges,
    selection: { ...this.selection },
    backward: this.selectionBackward,
  });

  // Rewinds or replays one history entry: the text by splicing its edits
  // (no pipeline - the ranges come from the snapshot, not from adjusting),
  // then the ranges and selection `target` holds.
  private restore(
    edits: readonly TextEdit[],
    direction: 'undo' | 'redo',
    target: ModelSnapshot
  ): void {
    this.session.scoped('processing', () => {
      let text = this.text;
      if (direction === 'undo') {
        for (let i = edits.length - 1; i >= 0; i--) {
          const { editStart, deletedText, insertedText } = edits[i]!;
          text =
            text.slice(0, editStart) +
            deletedText +
            text.slice(editStart + insertedText.length);
        }
      } else {
        for (const { editStart, deletedText, insertedText } of edits) {
          text =
            text.slice(0, editStart) +
            insertedText +
            text.slice(editStart + deletedText.length);
        }
      }
      this.text = text;
      // Fresh objects from the history: the stores may mutate them.
      this.formattingStore.setRanges([...target.formatting]);
      this.blockStore.setRanges([...target.blocks]);
      this.selection = { ...target.selection };
      this.selectionBackward = target.backward;
    });
    this.typing.resetForSelectionChange(this.selection);
    this.render();
    this.scrollCaretIntoView();
    this.emitTextEdited();
  }

  private recordFormatting(): void {
    this.history.recordFormatting(this.captureSnapshot);
  }

  // A scripted caret write does not scroll. Only after edits: a selection
  // the user moved is already in view.
  private scrollCaretIntoView(): void {
    if (!this.hasFocus()) {
      return;
    }
    const box = this.caretBoxAtOffset(this.selection.end);
    if (box !== null && !isZeroBox(box)) {
      scrollBoxIntoView(this.root, box);
    }
  }

  private render(): void {
    // The IME owns the DOM; the render after `compositionend` catches up.
    if (this.session.isComposing) {
      return;
    }
    this.session.scoped('formatting', () => {
      this.root.toggleAttribute(
        'data-empty',
        this.text.length === 0 && this.blockStore.isEmpty
      );
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
    // Moving the selection under an IME moves its composition with it.
    if (!this.hasFocus() || this.session.isComposing) {
      return;
    }
    const domSelection = this.root.ownerDocument.getSelection();
    if (domSelection === null) {
      return;
    }
    const { start, end } = this.selection;
    const collapsed = start === end;
    const anchorOffset = this.selectionBackward ? end : start;
    const focusOffset = this.selectionBackward ? start : end;
    const current = this.mapper.modelSelectionFromDom(domSelection);
    if (
      current !== null &&
      current.anchor === anchorOffset &&
      current.focus === focusOffset &&
      isCaret(domSelection) === collapsed
    ) {
      return;
    }
    const anchor = this.mapper.domPositionFromModelOffset(anchorOffset);
    const focus = collapsed
      ? anchor
      : this.mapper.domPositionFromModelOffset(focusOffset);
    if (anchor === null || focus === null) {
      return;
    }
    domSelection.setBaseAndExtent(
      anchor.node,
      anchor.offset,
      focus.node,
      focus.offset
    );
  }

  private hasFocus(): boolean {
    return this.root.contains(this.root.ownerDocument.activeElement);
  }

  private setOwnedAttribute(name: string, value: string): void {
    this.root.setAttribute(name, value);
    this.ownedAttributes.push(name);
  }

  private emitText(): void {
    if (this.session.shouldSuppressEvents) {
      return;
    }
    this.callbacks.onChangeText?.(this.text);
  }

  private emitSelection(): void {
    if (this.session.shouldSuppressEvents) {
      return;
    }
    this.callbacks.onChangeSelection?.(this.selection);
  }

  private emitState(): void {
    if (this.session.shouldSuppressEvents) {
      return;
    }
    const state = buildInputState(
      this.formattingStore,
      this.blockStore,
      this.typing,
      this.selection,
      this.text
    );
    if (
      this.lastEmittedState !== null &&
      sameInputState(state, this.lastEmittedState)
    ) {
      return;
    }
    this.lastEmittedState = state;
    this.callbacks.onChangeState?.(state);
  }

  private emitMarkdown(): void {
    if (
      this.session.shouldSuppressEvents ||
      !this.markdownEmitEnabled ||
      !this.callbacks.onChangeMarkdown
    ) {
      return;
    }
    const markdown = this.getMarkdown();
    if (markdown === this.lastEmittedMarkdown) {
      return;
    }
    this.lastEmittedMarkdown = markdown;
    this.callbacks.onChangeMarkdown(markdown);
  }

  // Only when the answer flips, so typing emits nothing past its first key.
  private emitHistoryState(): void {
    if (this.session.shouldSuppressEvents) {
      return;
    }
    const state = this.history.state;
    if (
      state.canUndo === this.lastEmittedHistory.canUndo &&
      state.canRedo === this.lastEmittedHistory.canRedo
    ) {
      return;
    }
    this.lastEmittedHistory = state;
    this.callbacks.onChangeHistoryState?.(state);
  }

  private emitTextEdited(): void {
    this.emitText();
    this.emitSelection();
    this.emitState();
    this.emitMarkdown();
    this.emitHistoryState();
  }

  private emitFormattingChanged(): void {
    this.emitState();
    this.emitMarkdown();
    this.emitHistoryState();
  }

  private emitSelectionMoved(): void {
    this.emitSelection();
    this.emitState();
  }
}

interface CaretBox {
  left: number;
  top: number;
  width: number;
  height: number;
}

// The viewport box of a caret at `position`. Uses the last client rect: at a
// soft wrap the bounding box is anchored at the previous line's end. An empty
// line's caret (before its lone `<br>`) has no rects in Blink or WebKit, so
// the `<br>` stands in: it respects list indent and RTL, and has text height.
function caretBoxAt(document: Document, position: DomPosition): CaretBox {
  const range = document.createRange();
  range.setStart(position.node, position.offset);
  range.collapse(true);
  // Neither is implemented by every DOM (jsdom has neither).
  if (typeof range.getClientRects === 'function') {
    const rects = range.getClientRects();
    const last = rects.length > 0 ? rects[rects.length - 1]! : null;
    if (last !== null && !isZeroBox(last)) {
      return last;
    }
  }
  const rect =
    typeof range.getBoundingClientRect === 'function'
      ? range.getBoundingClientRect()
      : ZERO_BOX;
  if (!isZeroBox(rect)) {
    return rect;
  }
  const element =
    position.node.nodeType === Node.ELEMENT_NODE
      ? (position.node as Element)
      : position.node.parentElement;
  if (element === null) {
    return rect;
  }
  for (const candidate of [lineBreakOf(element), element]) {
    const box = candidate?.getBoundingClientRect();
    if (box !== undefined && !isZeroBox(box)) {
      return { left: box.left, top: box.top, width: 0, height: box.height };
    }
  }
  return rect;
}

function lineBreakOf(line: Element): Element | null {
  for (const child of line.children) {
    if (child.nodeName === 'BR') {
      return child;
    }
  }
  return null;
}

const ZERO_BOX: CaretBox = { left: 0, top: 0, width: 0, height: 0 };

// Two physical pixels, as Android reports it (`2f / density`).
function caretWidth(document: Document): number {
  return 2 / (document.defaultView?.devicePixelRatio || 1);
}

// `scrollIntoView({ block: 'nearest' })` for a rect: scrolling the run span
// would align a multi-line run by its edge, not by the caret.
function scrollBoxIntoView(element: HTMLElement, box: CaretBox): void {
  const document = element.ownerDocument;
  const view = document.defaultView;
  let { top, left } = box;
  const { width, height } = box;
  for (
    let current: HTMLElement | null = element;
    current !== null &&
    current !== document.body &&
    current !== document.documentElement;
    current = current.parentElement
  ) {
    if (!isScrollContainer(current)) {
      continue;
    }
    const rect = current.getBoundingClientRect();
    const viewTop = rect.top + current.clientTop;
    const viewLeft = rect.left + current.clientLeft;
    const dy = scrollDelta(top, height, viewTop, current.clientHeight);
    const dx = scrollDelta(left, width, viewLeft, current.clientWidth);
    if (dy === 0 && dx === 0) {
      continue;
    }
    const scrollTop = current.scrollTop;
    const scrollLeft = current.scrollLeft;
    current.scrollTop += dy;
    current.scrollLeft += dx;
    top -= current.scrollTop - scrollTop;
    left -= current.scrollLeft - scrollLeft;
  }
  if (view === null) {
    return;
  }
  const dy = scrollDelta(top, height, 0, view.innerHeight);
  const dx = scrollDelta(left, width, 0, view.innerWidth);
  if (dy !== 0 || dx !== 0) {
    view.scrollBy(dx, dy);
  }
}

function scrollDelta(
  start: number,
  size: number,
  viewStart: number,
  viewSize: number
): number {
  if (start < viewStart) {
    return start - viewStart;
  }
  const overflow = start + size - (viewStart + viewSize);
  // A box taller than the view keeps its start in view.
  return overflow > 0 ? Math.min(overflow, start - viewStart) : 0;
}

function isScrollContainer(element: HTMLElement): boolean {
  if (
    element.scrollHeight <= element.clientHeight &&
    element.scrollWidth <= element.clientWidth
  ) {
    return false;
  }
  const style = element.ownerDocument.defaultView?.getComputedStyle(element);
  return (
    style !== undefined &&
    /(auto|scroll|overlay)/.test(`${style.overflowY} ${style.overflowX}`)
  );
}

function isZeroBox(box: CaretBox): boolean {
  return box.left === 0 && box.top === 0 && box.width === 0 && box.height === 0;
}

function setAttributeIfAbsent(
  element: HTMLElement,
  name: string,
  value: string
): void {
  if (!element.hasAttribute(name)) {
    element.setAttribute(name, value);
  }
}

// Mod+Z undoes, Mod+Shift+Z redoes; Mod is Cmd on Apple platforms and Ctrl
// elsewhere, where Ctrl+Y redoes too.
function historyShortcut(
  event: KeyboardEvent,
  navigator: Navigator | null
): 'undo' | 'redo' | null {
  if (event.altKey) {
    return null;
  }
  const apple = isApplePlatform(navigator);
  const mod = apple
    ? event.metaKey && !event.ctrlKey
    : event.ctrlKey && !event.metaKey;
  if (!mod) {
    return null;
  }
  const key = event.key.toLowerCase();
  if (key === 'z') {
    return event.shiftKey ? 'redo' : 'undo';
  }
  if (key === 'y' && !apple && !event.shiftKey) {
    return 'redo';
  }
  return null;
}

function isApplePlatform(navigator: Navigator | null): boolean {
  const platform =
    (navigator as { userAgentData?: { platform?: string } } | null)
      ?.userAgentData?.platform ??
    navigator?.platform ??
    '';
  return /mac|iphone|ipad|ipod/i.test(platform);
}

// `insertText` and `insertReplacementText` carry their text on `data` in some
// engines and in the data transfer in others.
function insertedTextOf(event: InputEvent): string {
  return normalizeLineEndings(
    event.data ?? event.dataTransfer?.getData('text/plain') ?? ''
  );
}

// The buffer uses bare newlines, so a clipboard's line endings are converted
// rather than stored as text.
function normalizeLineEndings(text: string): string {
  return text.replace(/\r\n?/g, '\n');
}

// The plain text the DOM shows, one line per element child of the root, and
// `point`'s offset in it (null when outside the root). Walks the DOM as is,
// not through the mapper, which only knows the renderer's own lines.
export function readTextFromDom(
  root: HTMLElement,
  point: DomPosition | null = null
): { text: string; caret: number | null } {
  const lines: string[] = [];
  // Length of `lines.join('\n')` so far.
  let length = 0;
  let caret: number | null = null;
  const children = root.childNodes;
  for (let i = 0; i < children.length; i++) {
    const node = children[i]!;
    const isLine = node.nodeType === Node.ELEMENT_NODE;
    const text = node.textContent ?? '';
    // A text node an IME or an extension dropped directly under the root
    // belongs to the line it was dropped beside, not to a line of its own.
    const startsLine = isLine || lines.length === 0;
    const nodeStart = startsLine && lines.length > 0 ? length + 1 : length;
    if (point !== null && caret === null) {
      if (point.node === root && point.offset === i) {
        caret = nodeStart;
      } else if (point.node === node || node.contains(point.node)) {
        caret = nodeStart + textLengthWithin(node, point);
      }
    }
    if (!isLine && text.length === 0) {
      continue;
    }
    if (startsLine) {
      lines.push(text);
    } else {
      lines[lines.length - 1] += text;
    }
    length = nodeStart + text.length;
  }
  if (point !== null && caret === null && point.node === root) {
    caret = length;
  }
  return { text: lines.join('\n'), caret };
}

// The length of the text inside `container` before `point`, which lies in it.
function textLengthWithin(container: Node, point: DomPosition): number {
  if (point.node === container && point.node.nodeType === Node.TEXT_NODE) {
    return Math.min(point.offset, (container as Text).length);
  }
  const range = container.ownerDocument!.createRange();
  range.setStart(container, 0);
  range.setEnd(
    point.node,
    Math.min(
      point.offset,
      point.node.nodeType === Node.TEXT_NODE
        ? (point.node as Text).length
        : point.node.childNodes.length
    )
  );
  return range.toString().length;
}

// The one contiguous edit between two buffers, bounded by their shared prefix
// and suffix. A composition commits as a single replacement, so one window is
// all there is to find.
//
// Where prefix and suffix overlap (`a` + `apple` inserts at 0 or 1), `caret`
// picks the placement ending at it, like ProseMirror's `findDiff`; otherwise
// the longest prefix wins.
export function diffEdit(
  previous: string,
  next: string,
  caret: number | null = null
): { editStart: number; deletedText: string; insertedText: string } {
  const maxShared = Math.min(previous.length, next.length);

  let commonPrefix = 0;
  while (
    commonPrefix < maxShared &&
    previous[commonPrefix] === next[commonPrefix]
  ) {
    commonPrefix++;
  }
  let commonSuffix = 0;
  while (
    commonSuffix < maxShared &&
    previous[previous.length - 1 - commonSuffix] ===
      next[next.length - 1 - commonSuffix]
  ) {
    commonSuffix++;
  }

  let prefix = commonPrefix;
  if (caret !== null && commonPrefix + commonSuffix > maxShared) {
    // The suffix that ends the inserted text at the caret, kept within the
    // range where both windows still hold.
    prefix = clamp(
      maxShared - next.length + caret,
      maxShared - commonSuffix,
      commonPrefix
    );
  }
  let suffix = Math.min(commonSuffix, maxShared - prefix);

  // The stores index code units, so a boundary inside a surrogate pair would
  // leave half a character on each side of the edit.
  while (prefix > 0 && !isCodePointBoundary(next, prefix)) {
    prefix--;
  }
  while (suffix > 0 && !isCodePointBoundary(next, next.length - suffix)) {
    suffix--;
  }

  return {
    editStart: prefix,
    deletedText: previous.slice(prefix, previous.length - suffix),
    insertedText: next.slice(prefix, next.length - suffix),
  };
}

// Start of the word before `position`: the whitespace immediately before it,
// then the run of non-whitespace before that. A line break bounds the scan,
// so one press never reaches onto the previous line.
function wordStartBefore(text: string, position: number): number {
  let index = position;
  while (index > 0 && isInlineWhitespace(text[index - 1]!)) {
    index--;
  }
  while (index > 0 && isWordCharacter(text[index - 1]!)) {
    index--;
  }
  return index;
}

function wordEndAfter(text: string, position: number): number {
  let index = position;
  while (index < text.length && isInlineWhitespace(text[index]!)) {
    index++;
  }
  while (index < text.length && isWordCharacter(text[index]!)) {
    index++;
  }
  return index;
}

function lineStartBefore(text: string, position: number): number {
  return text.lastIndexOf('\n', position - 1) + 1;
}

function lineEndAfter(text: string, position: number): number {
  const next = text.indexOf('\n', position);
  return next === -1 ? text.length : next;
}

function isInlineWhitespace(char: string): boolean {
  return char !== '\n' && isWhitespace(char);
}

function isWordCharacter(char: string): boolean {
  return char !== '\n' && !isWhitespace(char);
}
