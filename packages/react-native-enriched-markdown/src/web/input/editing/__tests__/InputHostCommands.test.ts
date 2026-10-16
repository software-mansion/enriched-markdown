/**
 * @jest-environment jsdom
 */
// The imperative surface the wrapper drives: the selection and caret-rect
// commands, the read-only switch, and the markdown emit switch. Everything
// here is reachable only from a command or from a user action the editor is
// supposed to refuse, which is why it sits apart from the keystroke suite.
import {
  compose,
  lastState,
  mount,
  pressTab,
  selectRangeFocused,
  sendClipboard,
  sendInput,
  typeText,
} from './inputHostKit';

interface Box {
  left: number;
  top: number;
  width: number;
  height: number;
}

const ZERO_BOX: Box = { left: 0, top: 0, width: 0, height: 0 };

function asDomRect(box: Box): DOMRect {
  return {
    ...box,
    x: box.left,
    y: box.top,
    right: box.left + box.width,
    bottom: box.top + box.height,
    toJSON: () => box,
  } as DOMRect;
}

// jsdom lays nothing out, so every box a caret rect is computed from has to be
// supplied. Elements get theirs on the instance; the range is built inside the
// host, so that one goes on the prototype - which in jsdom does not carry
// `getBoundingClientRect` at all, so this defines it rather than spying.
function stubElementBox(element: Element, box: Box): void {
  element.getBoundingClientRect = () => asDomRect(box);
}

function stubRangeBox(box: Box): void {
  Range.prototype.getBoundingClientRect = () => asDomRect(box);
}

afterEach(() => {
  delete (Range.prototype as Partial<Range>).getBoundingClientRect;
  document.body.replaceChildren();
});

describe('setSelection', () => {
  it('clamps an out-of-range selection into the buffer', () => {
    const { host, root, selections } = mount();
    typeText(root, 'hello');

    host.setSelection(-5, 99);

    expect(selections.at(-1)).toEqual({ start: 0, end: 5 });
  });

  // iOS clamps `end` up to `start` rather than swapping the two, so a reversed
  // range collapses there as well.
  it('collapses a reversed range the way iOS does', () => {
    const { host, root, selections } = mount();
    typeText(root, 'hello');

    host.setSelection(4, 1);

    expect(selections.at(-1)).toEqual({ start: 4, end: 4 });
  });

  // Clamping into the buffer is not enough on its own: the seam inside a
  // surrogate pair is in bounds, and an edit at an offset there would cut the
  // pair in half and leave two lone surrogates in the text the app reads back.
  it('snaps an offset off the seam inside a surrogate pair', () => {
    const { host, root, selections, texts } = mount();
    typeText(root, '\u{1F389}abc');

    host.setSelection(1, 1);
    expect(selections.at(-1)).toEqual({ start: 0, end: 0 });

    host.insertText('X');
    expect(host.value).toBe('X\u{1F389}abc');
    expect(texts.at(-1)).toBe('X\u{1F389}abc');
  });

  it('snaps both ends of a range off their seams', () => {
    const { host, root, selections } = mount();
    typeText(root, '\u{1F389}\u{1F389}');

    host.setSelection(1, 3);

    expect(selections.at(-1)).toEqual({ start: 0, end: 2 });
  });

  it('leaves an offset that already sits on a boundary alone', () => {
    const { host, root, selections } = mount();
    typeText(root, 'ab\u{1F389}cd');

    host.setSelection(2, 4);

    expect(selections.at(-1)).toEqual({ start: 2, end: 4 });
  });

  it('reports the state of the line it moved to', () => {
    const { host, states } = mount();
    host.insertText('head\nbody');
    host.setSelection(0, 0);
    host.toggleHeading(1);
    expect(lastState(states).heading).toEqual({ isActive: true, level: 1 });

    host.setSelection(6, 6);

    expect(lastState(states).heading).toEqual({ isActive: false, level: 0 });
  });

  // `writeSelectionToDom` declines to write while the editor is unfocused, and
  // the browser places its own caret the moment focus arrives. Without the
  // focus handler putting the model back, a `setSelection` issued before the
  // focus would be silently replaced by that caret.
  it('survives a focus that arrives after it', () => {
    const { host, root, selections } = mount();
    typeText(root, 'hello world');
    root.blur();

    host.setSelection(2, 5);
    expect(document.getSelection()!.toString()).toBe('');

    root.focus();
    expect(document.getSelection()!.toString()).toBe('llo');

    const emitted = selections.length;
    document.dispatchEvent(new Event('selectionchange'));
    expect(selections.length).toBe(emitted);
  });
});

describe('caretRect', () => {
  it('answers in coordinates relative to the editor', () => {
    const { host, root } = mount();
    typeText(root, 'hello');
    stubElementBox(root, { left: 124, top: 158, width: 300, height: 40 });
    stubRangeBox({ left: 160, top: 170, width: 2, height: 18 });

    expect(host.caretRect()).toEqual({ x: 36, y: 12, width: 2, height: 18 });
  });

  // An empty line renders as a lone <br>, so its caret resolves to the
  // paragraph element, and a range collapsed at an element boundary has no
  // client rects in Blink or WebKit: `getBoundingClientRect` answers an
  // all-zero box there. Subtracting the editor's own position from that box
  // would report the editor's position negated.
  it('falls back to the line box on an empty line', () => {
    const { host, root } = mount();
    stubElementBox(root, { left: 124, top: 158, width: 300, height: 40 });
    stubElementBox(root.firstElementChild!, {
      left: 136,
      top: 166,
      width: 280,
      height: 20,
    });
    stubRangeBox(ZERO_BOX);

    expect(host.caretRect()).toEqual({ x: 12, y: 8, width: 0, height: 20 });
  });

  it('keeps the zero box when the line has no box either', () => {
    const { host } = mount();
    stubRangeBox(ZERO_BOX);

    expect(host.caretRect()).toEqual({ x: 0, y: 0, width: 0, height: 0 });
  });
});

// `editable` is the web spelling of `_textView.editable = NO` and
// `view.isEnabled = false`. It refuses what the user does, and leaves the
// imperative commands working, which is what both natives do.
describe('a read-only editor', () => {
  it('cancels every edit the keyboard asks for', () => {
    const { host, root } = mount();
    typeText(root, 'hello');

    host.setEditable(false);
    typeText(root, '!');
    sendInput(root, 'deleteContentBackward');

    expect(host.value).toBe('hello');
    expect(pressTab(root).defaultPrevented).toBe(false);
  });

  it('refuses a cut, and writes nothing to the clipboard', () => {
    const { host, root } = mount();
    typeText(root, 'hello');
    selectRangeFocused(root, 1, 4);

    host.setEditable(false);
    const written = sendClipboard(root, 'cut');

    expect(host.value).toBe('hello');
    expect([...written]).toEqual([]);
  });

  it('refuses a paste', () => {
    const { host, root } = mount();
    typeText(root, 'hello');

    host.setEditable(false);
    sendClipboard(root, 'paste', 'pasted');

    expect(host.value).toBe('hello');
  });

  // Flipping `editable` while an IME holds the DOM is the one way composed
  // text can land on a read-only editor. The model must not take it, and the
  // nodes the IME left behind still have to go.
  it('discards a composition that ends on it', () => {
    const { host, root } = mount();
    typeText(root, 'hello');

    host.setEditable(false);
    compose(root, 'hello world');

    expect(host.value).toBe('hello');
    expect(root.textContent).toBe('hello');
  });

  it('still takes the imperative commands', () => {
    const { host, root } = mount();
    typeText(root, 'hello');

    host.setEditable(false);
    host.insertText('!');

    expect(host.value).toBe('hello!');
  });
});

describe('setMarkdownEmitEnabled', () => {
  // Serializing the whole document after every edit is only worth doing when
  // something is listening, and the callback alone cannot answer that: a
  // wrapper forwarding the event supplies one either way.
  it('stops the per-edit serialization while nothing is listening', () => {
    const { host, root, markdowns } = mount();

    host.setMarkdownEmitEnabled(false);
    typeText(root, 'hi');
    expect(markdowns).toEqual([]);

    host.setMarkdownEmitEnabled(true);
    typeText(root, '!');
    expect(markdowns).toEqual(['hi!']);
  });

  it('leaves the other events alone', () => {
    const { host, root, texts, selections, states } = mount();

    host.setMarkdownEmitEnabled(false);
    typeText(root, 'hi');

    expect(texts).toEqual(['hi']);
    expect(selections.length).toBeGreaterThan(0);
    expect(states.length).toBeGreaterThan(0);
  });
});

describe('an empty line the selection mapping cannot see into', () => {
  // Every position inside an empty line maps to the one model offset the line
  // occupies, so a DOM range stretched across it reports as a collapsed
  // caret. The model has not moved and nothing is emitted, but the browser is
  // still showing a highlight that has to be written back.
  it('has its stretched dom selection rewritten', () => {
    const { host, root, selections } = mount();
    host.insertText('a\n\nb');
    root.focus();
    host.setSelection(2, 2);

    const emptyLine = root.children[1]!;
    document.getSelection()!.setBaseAndExtent(emptyLine, 0, emptyLine, 1);
    expect(document.getSelection()!.isCollapsed).toBe(false);

    const emitted = selections.length;
    document.dispatchEvent(new Event('selectionchange'));

    expect(document.getSelection()!.isCollapsed).toBe(true);
    expect(selections.length).toBe(emitted);
  });
});

describe('destroy', () => {
  it('takes the empty-document marker with it', () => {
    const { host, root } = mount();
    expect(root.hasAttribute('data-empty')).toBe(true);

    host.destroy();

    expect(root.hasAttribute('data-empty')).toBe(false);
  });
});
