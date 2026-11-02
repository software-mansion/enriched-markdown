// The DOM plumbing every `InputHost` suite needs. jsdom dispatches none of
// the events a browser would raise by itself - `beforeinput`,
// `selectionchange`, the clipboard pair - so each one is built here by hand,
// in the shape the host reads it.
import type { HistoryState } from '../EditHistory';
import { InputHost, type InputHostOptions } from '../InputHost';
import type { InputState } from '../InputState';
import type { RangeBounds } from '../../model/rangeBounds';

export interface MountedHost {
  root: HTMLElement;
  host: InputHost;
  texts: string[];
  states: InputState[];
  selections: RangeBounds[];
  markdowns: string[];
  histories: HistoryState[];
}

export function mount(options?: InputHostOptions): MountedHost {
  const root = document.createElement('div');
  document.body.appendChild(root);
  const texts: string[] = [];
  const states: InputState[] = [];
  const selections: RangeBounds[] = [];
  const markdowns: string[] = [];
  const histories: HistoryState[] = [];
  const host = new InputHost(
    root,
    {
      onChangeText: (text) => texts.push(text),
      onChangeState: (state) => states.push(state),
      onChangeSelection: (selection) => selections.push({ ...selection }),
      onChangeMarkdown: (markdown) => markdowns.push(markdown),
      onChangeHistoryState: (state) => histories.push(state),
    },
    options
  );
  return { root, host, texts, states, selections, markdowns, histories };
}

export function lastState(states: InputState[]): InputState {
  const state = states.at(-1);
  if (state === undefined) {
    throw new Error('no state was emitted');
  }
  return state;
}

export function pressTab(root: HTMLElement, shiftKey = false): KeyboardEvent {
  const event = new KeyboardEvent('keydown', {
    key: 'Tab',
    shiftKey,
    bubbles: true,
    cancelable: true,
  });
  root.dispatchEvent(event);
  return event;
}

export function pressKey(
  root: HTMLElement,
  key: string,
  modifiers: Pick<
    KeyboardEventInit,
    'ctrlKey' | 'metaKey' | 'shiftKey' | 'altKey'
  > = {}
): KeyboardEvent {
  const event = new KeyboardEvent('keydown', {
    key,
    ...modifiers,
    bubbles: true,
    cancelable: true,
  });
  root.dispatchEvent(event);
  return event;
}

// The text of every run carrying `style`, so a typing attribute can be read
// back off the rendered DOM the way the user sees it.
export function styledText(root: HTMLElement, style: string): string[] {
  return [...root.querySelectorAll(`.enrm-${style}`)].map(
    (run) => run.textContent ?? ''
  );
}

// The DOM point a model offset maps to, so the host reads a caret back out of
// the DOM the way a real one would. Walks the lines, then the runs within the
// line a styled range splits into several of.
export function domPointAt(
  root: HTMLElement,
  offset: number
): { node: Node; offset: number } {
  let remaining = offset;
  for (const line of root.children) {
    const length = (line.textContent ?? '').length;
    if (remaining <= length) {
      const walker = document.createTreeWalker(line, NodeFilter.SHOW_TEXT);
      let node = walker.nextNode();
      // An empty line holds a <br> and no text node.
      if (node === null) {
        return { node: line, offset: 0 };
      }
      while (remaining > (node.nodeValue ?? '').length) {
        const next = walker.nextNode();
        if (next === null) {
          break;
        }
        remaining -= (node.nodeValue ?? '').length;
        node = next;
      }
      return { node, offset: remaining };
    }
    remaining -= length + 1;
  }
  return { node: root, offset: 0 };
}

export function caretAt(root: HTMLElement, offset: number): void {
  const point = domPointAt(root, offset);
  document
    .getSelection()!
    .setBaseAndExtent(point.node, point.offset, point.node, point.offset);
}

export function selectRange(
  root: HTMLElement,
  start: number,
  end: number
): void {
  const from = domPointAt(root, start);
  const to = domPointAt(root, end);
  document
    .getSelection()!
    .setBaseAndExtent(from.node, from.offset, to.node, to.offset);
}

// A toolbar command reads the model selection, which in a browser arrives
// through `selectionchange` while the editor has focus. jsdom dispatches
// neither, so both halves are done by hand.
export function selectRangeFocused(
  root: HTMLElement,
  start: number,
  end: number
): void {
  root.focus();
  selectRange(root, start, end);
  document.dispatchEvent(new Event('selectionchange'));
}

// Plays the browser's part too: plain typing inside a run is left to the
// browser (see `NativeEdit`), and jsdom performs no edits, so an uncancelled
// `beforeinput` is followed here by the insert and the `input` a browser
// would make.
export function typeText(root: HTMLElement, data: string): void {
  const event = new InputEvent('beforeinput', {
    inputType: 'insertText',
    data,
    bubbles: true,
    cancelable: true,
  });
  root.dispatchEvent(event);
  if (!event.defaultPrevented) {
    insertAtCaretAsBrowser(root, data);
  }
}

// The bare event, with no browser behind it: for asserting what the host does
// with an event it should not act on.
export function dispatchTyping(root: HTMLElement, data: string): void {
  root.dispatchEvent(
    new InputEvent('beforeinput', {
      inputType: 'insertText',
      data,
      bubbles: true,
      cancelable: true,
    })
  );
}

function insertAtCaretAsBrowser(root: HTMLElement, data: string): void {
  const selection = document.getSelection()!;
  const node = selection.anchorNode as Text;
  const offset = selection.anchorOffset;
  node.insertData(offset, data);
  // A browser leaves the caret after what it typed; `insertData` alone
  // leaves a caret at the insertion point before it.
  selection.setBaseAndExtent(
    node,
    offset + data.length,
    node,
    offset + data.length
  );
  root.dispatchEvent(
    new InputEvent('input', { inputType: 'insertText', data, bubbles: true })
  );
}

export function sendInput(root: HTMLElement, inputType: string): void {
  root.dispatchEvent(
    new InputEvent('beforeinput', {
      inputType,
      bubbles: true,
      cancelable: true,
    })
  );
}

export function sendClipboard(
  root: HTMLElement,
  type: 'cut' | 'paste',
  incoming = ''
): Map<string, string> {
  // jsdom has no ClipboardEvent, and the host only ever reaches for
  // `clipboardData`.
  const event = new Event(type, { bubbles: true, cancelable: true });
  const written = new Map<string, string>();
  Object.defineProperty(event, 'clipboardData', {
    value: {
      getData: () => incoming,
      setData: (mime: string, value: string) => written.set(mime, value),
    },
  });
  root.dispatchEvent(event);
  return written;
}

export function compose(root: HTMLElement, composed: string): void {
  root.dispatchEvent(new Event('compositionstart', { bubbles: true }));
  // What the IME does while the model stands back: it writes its result
  // straight into the text node the renderer put there.
  const text = root.firstElementChild!.firstChild!.firstChild as Text;
  text.nodeValue = composed;
  root.dispatchEvent(new Event('compositionend', { bubbles: true }));
}

// A paste is parsed as markdown, asynchronously, like `insertText`: sends the
// paste, then waits a few turns for the parse to land.
export async function pasteText(
  root: HTMLElement,
  incoming: string,
  mime = 'text/plain'
): Promise<void> {
  const event = new Event('paste', { bubbles: true, cancelable: true });
  Object.defineProperty(event, 'clipboardData', {
    value: {
      getData: (type: string) => (type === mime ? incoming : ''),
      setData: () => {},
    },
  });
  root.dispatchEvent(event);
  for (let turn = 0; turn < 10; turn++) {
    await new Promise((resolve) => setTimeout(resolve, 0));
  }
}
