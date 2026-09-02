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
import {
  graphemeLengthBefore,
  graphemeLengthAfter,
  isCodePointBoundary,
  isWhitespace,
} from '../utils';

export interface InputHostCallbacks {
  onChangeText?: (text: string) => void;
  onChangeSelection?: (selection: RangeBounds) => void;
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
  private readonly pipeline: EditPipeline;
  private readonly renderer: DomRenderer;
  private readonly mapper: SelectionMapper;
  // Attributes this host set itself, and so the only ones it removes on
  // teardown: `role` and `aria-multiline` are set only when the node does not
  // already carry them, so a consumer's own value is never ours to undo.
  private readonly ownedAttributes: string[] = [];

  private text = '';
  private selection: RangeBounds = { start: 0, end: 0 };
  private destroyed = false;
  // Bumped by every import, so one still parsing can tell that a later import
  // has overtaken it. Only imports count: a user edit cannot race an import,
  // because the editor is inert while one is parsing.
  private importGeneration = 0;
  private pendingImports = 0;

  constructor(
    root: HTMLElement,
    callbacks: InputHostCallbacks = {},
    options: InputHostOptions = {}
  ) {
    this.root = root;
    this.callbacks = callbacks;
    this.pipeline = new EditPipeline(this.formattingStore, this.blockStore);
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
    root.addEventListener('compositionstart', this.handleCompositionStart);
    root.addEventListener('compositionend', this.handleCompositionEnd);
    root.addEventListener('blur', this.handleBlur);
    root.addEventListener('cut', this.handleCut);
    root.addEventListener('paste', this.handlePaste);
    root.ownerDocument.addEventListener(
      'selectionchange',
      this.handleSelectionChange
    );

    this.render();
  }

  destroy(): void {
    if (this.destroyed) {
      return;
    }
    this.destroyed = true;
    this.session.endComposition();

    this.root.removeEventListener('beforeinput', this.handleBeforeInput);
    this.root.removeEventListener(
      'compositionstart',
      this.handleCompositionStart
    );
    this.root.removeEventListener('compositionend', this.handleCompositionEnd);
    this.root.removeEventListener('blur', this.handleBlur);
    this.root.removeEventListener('cut', this.handleCut);
    this.root.removeEventListener('paste', this.handlePaste);
    this.root.ownerDocument.removeEventListener(
      'selectionchange',
      this.handleSelectionChange
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

  // The prop path (`defaultValue` and friends): loads the markdown without
  // reporting it back, because the app already has this value. Matches
  // Android, which holds its importing phase across the whole import, and
  // iOS, whose `importMarkdown` emits nothing.
  async importValue(markdown: string): Promise<void> {
    await this.loadValue(markdown);
  }

  // The imperative command path: loads the markdown and then reports it, the
  // way iOS's `setValue:` command re-emits once the import returns. Keeping
  // the two apart matters at the wrapper, where one `setValue` serving both
  // would make mounting with a `defaultValue` fire `onChangeText` with the
  // value the app just supplied.
  async setValue(markdown: string): Promise<void> {
    if (await this.loadValue(markdown)) {
      this.emitChanges();
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

    const { plainText, formattingRanges, blockRanges } = parsed;
    this.session.scoped('importing', () => {
      this.text = plainText;
      this.formattingStore.setRanges(formattingRanges);
      this.blockStore.setRanges(blockRanges);
      this.selection = { start: plainText.length, end: plainText.length };
    });
    this.render();
    return true;
  }

  private readonly handleBeforeInput = (event: InputEvent): void => {
    // The browser owns the DOM during a composition and `beforeinput` for
    // `insertCompositionText` is not cancelable in every engine, so the model
    // stays out of the way and reads the result back on `compositionend`.
    if (event.isComposing || this.session.isComposing) {
      return;
    }
    // Default-deny: unhandled input types become no-ops, never native edits.
    event.preventDefault();
    // An import is parsing: the value the app asked for is about to replace
    // everything, so an edit now would be overwritten anyway.
    if (this.pendingImports > 0) {
      return;
    }
    this.syncSelectionFromDom();

    switch (event.inputType) {
      case 'insertText':
        this.replaceSelection(event.data ?? '');
        break;
      // Autocorrect and spellcheck replacements address their own range
      // rather than the selection.
      case 'insertReplacementText':
        this.replaceTargetRange(event, replacementTextOf(event));
        break;
      case 'insertParagraph':
      case 'insertLineBreak':
        this.insertNewline();
        break;
      case 'deleteContentBackward':
        this.deleteBackwardTo(
          this.selection.start -
            graphemeLengthBefore(this.text, this.selection.start)
        );
        break;
      case 'deleteContentForward':
        this.deleteForwardTo(
          this.selection.end +
            graphemeLengthAfter(this.text, this.selection.end)
        );
        break;
      case 'deleteWordBackward':
        this.deleteBackwardTo(wordStartBefore(this.text, this.selection.start));
        break;
      case 'deleteWordForward':
        this.deleteForwardTo(wordEndAfter(this.text, this.selection.end));
        break;
      case 'deleteSoftLineBackward':
      case 'deleteHardLineBackward':
        this.deleteBackwardTo(lineStartBefore(this.text, this.selection.start));
        break;
      case 'deleteSoftLineForward':
      case 'deleteHardLineForward':
        this.deleteForwardTo(lineEndAfter(this.text, this.selection.end));
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
      // - `historyUndo` / `historyRedo`: every model edit is a scripted
      //   `nodeValue` write, so the browser's undo stack is empty and there is
      //   nothing to diverge from - but there is no undo either until the
      //   model keeps its own stack.
      // - `insertFromDrop`: needs a caret-from-point mapping to know where the
      //   drop landed. Denying it is inert rather than wrong.
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
    this.session.beginComposition();
  };

  private readonly handleCompositionEnd = (): void => {
    this.session.endComposition();
    this.readBackFromDom();
  };

  private readonly handleBlur = (): void => {
    // A composition abandoned by a blur does not always fire
    // `compositionend`, and a latched composition flag makes the editor
    // read-only: every `beforeinput` short-circuits.
    if (this.session.isComposing) {
      this.session.endComposition();
      this.readBackFromDom();
    }
  };

  private readonly handleCut = (event: ClipboardEvent): void => {
    // The UA writes the clipboard and then performs the deletion, whose
    // `beforeinput` arrives as `deleteByCut` and gets cancelled. Taking over
    // both halves is what stops a cut from copying the text and leaving it
    // in place.
    event.preventDefault();
    if (this.session.isComposing || this.pendingImports > 0) {
      return;
    }
    this.syncSelectionFromDom();
    const { start, end } = this.selection;
    if (start === end) {
      return;
    }
    event.clipboardData?.setData('text/plain', this.text.slice(start, end));
    this.applyEdit(start, this.text.slice(start, end), '');
  };

  private readonly handlePaste = (event: ClipboardEvent): void => {
    event.preventDefault();
    if (this.session.isComposing || this.pendingImports > 0) {
      return;
    }
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
  private readBackFromDom(): void {
    if (this.destroyed) {
      return;
    }
    const domText = readTextFromDom(this.root);
    if (domText === this.text) {
      // Nothing to recover, but the IME may still have left non-canonical
      // nodes behind; a render replaces them.
      this.render();
      return;
    }
    const { editStart, deletedText, insertedText } = diffEdit(
      this.text,
      domText
    );
    this.applyEdit(editStart, deletedText, insertedText);
  }

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

  private replaceTargetRange(event: InputEvent, insertedText: string): void {
    const target = this.modelRangeFromTargetRanges(event);
    if (target === null) {
      return;
    }
    this.applyEdit(
      target.start,
      this.text.slice(target.start, target.end),
      insertedText
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
    return { start: Math.min(start, end), end: Math.max(start, end) };
  }

  // Deletes back to `target`. A target that makes no progress - a word or
  // line delete with the caret already at a line start - falls back to one
  // character, which is the newline, so the press joins the lines instead of
  // doing nothing.
  private deleteBackwardTo(target: number): void {
    const { start, end } = this.selection;
    if (start !== end) {
      this.replaceSelection('');
      return;
    }
    if (start === 0) {
      return;
    }
    const from =
      target < start ? target : start - graphemeLengthBefore(this.text, start);
    this.applyEdit(from, this.text.slice(from, start), '');
  }

  private deleteForwardTo(target: number): void {
    const { start, end } = this.selection;
    if (start !== end) {
      this.replaceSelection('');
      return;
    }
    if (end >= this.text.length) {
      return;
    }
    const to =
      target > end ? target : end + graphemeLengthAfter(this.text, end);
    this.applyEdit(end, this.text.slice(end, to), '');
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
    if (!this.hasFocus()) {
      return;
    }
    const domSelection = this.root.ownerDocument.getSelection();
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

  private hasFocus(): boolean {
    return this.root.contains(this.root.ownerDocument.activeElement);
  }

  private setOwnedAttribute(name: string, value: string): void {
    this.root.setAttribute(name, value);
    this.ownedAttributes.push(name);
  }

  private emitChanges(): void {
    if (this.session.shouldSuppressEvents) {
      return;
    }
    this.callbacks.onChangeText?.(this.text);
    this.callbacks.onChangeSelection?.(this.selection);
  }
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

// `insertReplacementText` carries its text on `data` in some engines and in
// the data transfer in others.
function replacementTextOf(event: InputEvent): string {
  return event.data ?? event.dataTransfer?.getData('text/plain') ?? '';
}

// The buffer uses bare newlines, so a clipboard's line endings are converted
// rather than stored as text.
function normalizeLineEndings(text: string): string {
  return text.replace(/\r\n?/g, '\n');
}

// Recovers the plain text the DOM currently shows, in the shape `render`
// writes it: one line per element child of the root.
function readTextFromDom(root: HTMLElement): string {
  const lines: string[] = [];
  for (const node of root.childNodes) {
    if (node.nodeType === Node.ELEMENT_NODE) {
      lines.push(node.textContent ?? '');
      continue;
    }
    // A text node an IME or an extension dropped directly under the root
    // belongs to the line it was dropped beside, not to a line of its own.
    const text = node.textContent ?? '';
    if (text.length === 0) {
      continue;
    }
    if (lines.length === 0) {
      lines.push(text);
    } else {
      lines[lines.length - 1] += text;
    }
  }
  return lines.join('\n');
}

// The one contiguous edit between two buffers, bounded by their shared prefix
// and suffix. A composition commits as a single replacement, so one window is
// all there is to find.
function diffEdit(
  previous: string,
  next: string
): { editStart: number; deletedText: string; insertedText: string } {
  const maxShared = Math.min(previous.length, next.length);

  let prefix = 0;
  while (prefix < maxShared && previous[prefix] === next[prefix]) {
    prefix++;
  }
  // The stores index code units, so a boundary inside a surrogate pair would
  // leave half a character on each side of the edit.
  while (prefix > 0 && !isCodePointBoundary(next, prefix)) {
    prefix--;
  }

  let suffix = 0;
  while (
    suffix < maxShared - prefix &&
    previous[previous.length - 1 - suffix] === next[next.length - 1 - suffix]
  ) {
    suffix++;
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
