/**
 * @jest-environment jsdom
 */
import {
  caretAt,
  dispatchTyping,
  domPointAt,
  mount,
  selectRangeFocused,
  styledText,
} from './inputHostKit';

// Plain typing and one-character deletes inside a run are left to the
// browser, so the host skips rewriting the text node and restoring the caret.
// jsdom performs no edits, so each test plays the browser's part by hand:
// the edit it was allowed to make, then the `input` that reports it.

afterEach(() => {
  document.body.replaceChildren();
  jest.restoreAllMocks();
  jest.useRealTimers();
});

function beforeInput(
  root: HTMLElement,
  inputType: string,
  init: InputEventInit = {},
  target?: { start: number; end: number }
): InputEvent {
  const event = new InputEvent('beforeinput', {
    inputType,
    bubbles: true,
    cancelable: true,
    ...init,
  });
  if (target !== undefined) {
    const from = domPointAt(root, target.start);
    const to = domPointAt(root, target.end);
    Object.defineProperty(event, 'getTargetRanges', {
      value: () => [
        {
          startContainer: from.node,
          startOffset: from.offset,
          endContainer: to.node,
          endOffset: to.offset,
          collapsed: target.start === target.end,
        },
      ],
    });
  }
  root.dispatchEvent(event);
  return event;
}

function input(root: HTMLElement, inputType: string): void {
  root.dispatchEvent(new InputEvent('input', { inputType, bubbles: true }));
}

// Types `data` the way a browser does once it is let through.
function browserTypes(root: HTMLElement, data: string): InputEvent {
  const event = beforeInput(root, 'insertText', { data });
  if (!event.defaultPrevented) {
    const selection = document.getSelection()!;
    const node = selection.anchorNode as Text;
    const offset = selection.anchorOffset;
    node.insertData(offset, data);
    selection.collapse(node, offset + data.length);
    input(root, 'insertText');
  }
  return event;
}

function focusedWith(text: string) {
  const mounted = mount();
  mounted.root.focus();
  dispatchTyping(mounted.root, text);
  return mounted;
}

describe('native edits', () => {
  it('lets plain typing inside a run through, and restores no caret', () => {
    const { root, host, texts } = focusedWith('helo');
    caretAt(root, 3);
    document.dispatchEvent(new Event('selectionchange'));
    const node = root.querySelector('span')!.firstChild as Text;
    const caretWrite = jest.spyOn(Selection.prototype, 'setBaseAndExtent');

    const event = browserTypes(root, 'l');

    expect(event.defaultPrevented).toBe(false);
    expect(host.value).toBe('hello');
    expect(texts.at(-1)).toBe('hello');
    expect(root.querySelector('span')!.firstChild).toBe(node);
    expect(caretWrite).not.toHaveBeenCalled();
  });

  it('lets typing at the end of a line through', () => {
    const { root, host } = focusedWith('ab');

    expect(browserTypes(root, 'c').defaultPrevented).toBe(false);
    expect(host.value).toBe('abc');
  });

  it('holds the model edit until the browser reports it', () => {
    const { root, host, texts } = focusedWith('ab');
    const before = texts.length;
    beforeInput(root, 'insertText', { data: 'c' });

    expect(host.value).toBe('abc');
    expect(texts).toHaveLength(before);
  });

  it('renders from the model when a pending style differs from the run', () => {
    const { root, host } = focusedWith('ab');
    host.toggleBold();

    expect(browserTypes(root, 'c').defaultPrevented).toBe(true);
    expect(styledText(root, 'strong')).toEqual(['c']);
  });

  // The caret on a boundary sits at the start of the following run, which is
  // where the browser would type; the model gives the character to the run
  // before it.
  it('renders from the model on a run boundary the browser would get wrong', () => {
    const { root, host } = focusedWith('abcd');
    selectRangeFocused(root, 0, 2);
    host.toggleBold();
    // The host's own caret write puts a boundary caret in the next run.
    host.setSelection(2, 2);
    expect(document.getSelection()!.anchorNode!.textContent).toBe('cd');

    expect(browserTypes(root, 'X').defaultPrevented).toBe(true);
    expect(styledText(root, 'strong')).toEqual(['abX']);
  });

  // The same offset reached from the other side - the end of the bold node -
  // is where the browser types into the bold run, as the model does.
  it('lets typing through at the end of the run the model extends', () => {
    const { root, host } = focusedWith('abcd');
    selectRangeFocused(root, 0, 2);
    host.toggleBold();
    caretAt(root, 2);
    document.dispatchEvent(new Event('selectionchange'));

    expect(browserTypes(root, 'X').defaultPrevented).toBe(false);
    expect(styledText(root, 'strong')).toEqual(['abX']);
  });

  it('lets a Backspace inside a run through', () => {
    const { root, host } = focusedWith('abc');
    const event = beforeInput(
      root,
      'deleteContentBackward',
      {},
      { start: 2, end: 3 }
    );
    expect(event.defaultPrevented).toBe(false);
    (root.querySelector('span')!.firstChild as Text).deleteData(2, 1);
    input(root, 'deleteContentBackward');

    expect(host.value).toBe('ab');
  });

  it('renders from the model a delete that would empty a run', () => {
    const { root, host } = focusedWith('abc');
    selectRangeFocused(root, 1, 2);
    host.toggleBold();
    caretAt(root, 2);
    const event = beforeInput(
      root,
      'deleteContentBackward',
      {},
      { start: 1, end: 2 }
    );

    expect(event.defaultPrevented).toBe(true);
    expect(host.value).toBe('ac');
    expect(styledText(root, 'strong')).toEqual([]);
  });

  it('leaves a delete without a target range to the model', () => {
    const { root, host } = focusedWith('abc');
    const event = beforeInput(root, 'deleteContentBackward');

    expect(event.defaultPrevented).toBe(true);
    expect(host.value).toBe('ab');
  });

  it('renders the model when the browser never performs the edit', () => {
    jest.useFakeTimers();
    const { root, host } = focusedWith('ab');
    beforeInput(root, 'insertText', { data: 'c' });
    jest.runAllTimers();

    expect(host.value).toBe('abc');
    expect(root.textContent).toBe('abc');
  });

  it('repairs the line when the browser edits somewhere else', () => {
    const { root, host } = focusedWith('ab');
    beforeInput(root, 'insertText', { data: 'c' });
    // An engine that wraps its insert in a node of its own.
    const line = root.firstElementChild!;
    line.appendChild(document.createElement('font')).textContent = 'c';
    input(root, 'insertText');

    expect(host.value).toBe('abc');
    expect(line.querySelector('font')).toBeNull();
    expect(root.textContent).toBe('abc');
  });

  it('settles before the next keystroke even without an input event', () => {
    const { root, host } = focusedWith('ab');
    beforeInput(root, 'insertText', { data: 'c' });
    browserTypes(root, 'd');

    expect(host.value).toBe('abcd');
    expect(root.textContent).toBe('abcd');
  });
});
