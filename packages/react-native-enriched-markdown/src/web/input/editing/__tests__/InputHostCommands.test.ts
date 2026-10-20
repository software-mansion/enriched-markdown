/**
 * @jest-environment jsdom
 */
// The imperative surface the wrapper drives: the selection and caret-rect
// commands, the read-only switch, and the markdown emit switch. Everything
// here is reachable only from a command or from a user action the editor is
// supposed to refuse, which is why it sits apart from the keystroke suite.
import {
  compose,
  dispatchTyping,
  lastState,
  mount,
  pressKey,
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

  // The natives take Int32 arguments; a fractional offset would otherwise
  // reach the stores and land an edit between characters of a range.
  it('drops the fraction of an offset', () => {
    const { host, root, selections } = mount();
    typeText(root, 'abcd');

    host.setSelection(1.7, 2.9);

    expect(selections.at(-1)).toEqual({ start: 1, end: 2 });
  });

  it('reads NaN as 0', () => {
    const { host, root, selections } = mount();
    typeText(root, 'abcd');

    host.setSelection(NaN, NaN);
    expect(selections.at(-1)).toEqual({ start: 0, end: 0 });

    host.insertText('X');
    expect(host.value).toBe('Xabcd');
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
    stubRangeBox({ left: 160, top: 170, width: 0, height: 18 });

    // Two physical pixels wide, as Android reports it.
    expect(host.caretRect()).toEqual({ x: 36, y: 12, width: 2, height: 18 });
  });

  // Native reports the caret in the editor's content, so a scrolled editor
  // adds its scroll offset rather than reporting where it sits on screen.
  it('adds the scroll offset and leaves out the border', () => {
    const { host, root } = mount();
    typeText(root, 'hello');
    stubElementBox(root, { left: 100, top: 100, width: 300, height: 40 });
    Object.defineProperty(root, 'clientTop', { value: 1 });
    Object.defineProperty(root, 'clientLeft', { value: 1 });
    root.scrollTop = 0;
    Object.defineProperty(root, 'scrollTop', { value: 50 });
    stubRangeBox({ left: 111, top: 121, width: 0, height: 18 });

    expect(host.caretRect()).toEqual({ x: 10, y: 70, width: 2, height: 18 });
  });

  // An empty line renders as a lone <br>, so its caret resolves to the
  // line element, and a range collapsed at an element boundary has no
  // client rects in Blink or WebKit: `getBoundingClientRect` answers an
  // all-zero box there. The <br> stands in: it sits after a list indent and
  // is as tall as the text rather than the line box.
  it('measures the line break on an empty line', () => {
    const { host, root } = mount();
    stubElementBox(root, { left: 124, top: 158, width: 300, height: 40 });
    stubElementBox(root.firstElementChild!, {
      left: 136,
      top: 166,
      width: 280,
      height: 26,
    });
    stubElementBox(root.querySelector('br')!, {
      left: 154,
      top: 168,
      width: 0,
      height: 22,
    });
    stubRangeBox(ZERO_BOX);

    expect(host.caretRect()).toEqual({ x: 30, y: 10, width: 2, height: 22 });
  });

  it('falls back to the line box when the line break has none', () => {
    const { host, root } = mount();
    stubElementBox(root, { left: 124, top: 158, width: 300, height: 40 });
    stubElementBox(root.firstElementChild!, {
      left: 136,
      top: 166,
      width: 280,
      height: 20,
    });
    stubRangeBox(ZERO_BOX);

    expect(host.caretRect()).toEqual({ x: 12, y: 8, width: 2, height: 20 });
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

// A command that changes nothing must not look like an edit to the app: no
// events, no render, and no undo entry to step through.
describe('a command that changes nothing', () => {
  it('insertText with empty text emits nothing at a caret', () => {
    const { host, root, texts, selections, markdowns } = mount();
    typeText(root, 'hi');
    const counts = [texts.length, selections.length, markdowns.length];

    host.insertText('');

    expect([texts.length, selections.length, markdowns.length]).toEqual(counts);
  });

  // The natives ignore it outright rather than deleting the selection.
  it('insertText with empty text leaves a selection in place', () => {
    const { host, root, texts } = mount();
    typeText(root, 'hello');
    host.setSelection(1, 4);
    const emitted = texts.length;

    host.insertText('');

    expect(host.value).toBe('hello');
    expect(texts).toHaveLength(emitted);
  });

  it('toggleHeading with a level that names no heading emits nothing', () => {
    const { host, root, states, markdowns, histories } = mount();
    typeText(root, 'hi');
    const html = root.innerHTML;
    const counts = [states.length, markdowns.length, histories.length];

    host.toggleHeading(9);

    expect(root.innerHTML).toBe(html);
    expect([states.length, markdowns.length, histories.length]).toEqual(counts);
  });

  it('toggleHeading with a bad level leaves no undo entry behind', () => {
    const { host, root } = mount();
    typeText(root, 'hi');

    host.toggleHeading(9);
    host.undo();

    expect(host.value).toBe('');
  });
});

describe('markdown emits', () => {
  // Bold at a caret only arms a typing attribute; the document is untouched.
  it('skip a change that leaves the markdown as it was', () => {
    const { host, root, markdowns, states } = mount();
    typeText(root, 'hi');
    const emitted = markdowns.length;
    const stateCount = states.length;

    host.toggleBold();

    expect(states.length).toBeGreaterThan(stateCount);
    expect(markdowns).toHaveLength(emitted);
  });

  it('report again after the emit switch is turned back on', () => {
    const { host, root, markdowns } = mount();
    typeText(root, 'hi');
    host.setMarkdownEmitEnabled(false);
    host.setMarkdownEmitEnabled(true);
    const emitted = markdowns.length;

    host.toggleHeading(9);
    typeText(root, '!');

    expect(markdowns.slice(emitted)).toEqual(['hi!']);
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

  // The wrapper drops its host on unmount; a direct user may keep calling
  // into one whose node is now theirs again.
  it('turns the commands into no-ops', () => {
    const { host, root, texts, markdowns, selections, states } = mount();
    typeText(root, 'ab');
    host.destroy();
    const emitted = [texts, markdowns, selections, states].map((e) => e.length);

    host.toggleBold();
    host.insertText('Z');
    host.toggleHeading(1);
    host.toggleUnorderedList();
    host.setSelection(0, 1);
    host.undo();

    expect(root.childNodes).toHaveLength(0);
    expect(host.value).toBe('ab');
    expect([texts, markdowns, selections, states].map((e) => e.length)).toEqual(
      emitted
    );
  });

  it('keeps the node non-editable', () => {
    const { host, root } = mount();
    host.destroy();

    host.setEditable(true);

    expect(root.hasAttribute('contenteditable')).toBe(false);
  });
});

describe('a selection ending at a line start', () => {
  // Chrome's triple-click on "one" maps to {0, 4}: through the next line's
  // start, holding nothing of it (review §2.3.3).
  it('leaves the next line out of a block command', () => {
    const { host } = mount();
    host.insertText('one\ntwo');

    host.setSelection(0, 4);
    host.toggleHeading(1);
    expect(host.getMarkdown()).toBe('# one\ntwo');

    host.setSelection(0, 4);
    host.toggleUnorderedList();
    expect(host.getMarkdown()).toBe('- one\ntwo');
  });
});

describe('a caret toggle inside a styled run', () => {
  // Review §2.4.1: the caret inherits a pending bold from the run, and the
  // first press used to drop only that copy, so typing stayed bold.
  it('unbolds what is typed next on the first press', () => {
    const { host, root, states } = mount();
    root.focus();
    typeText(root, 'abcdefgh');
    selectRangeFocused(root, 2, 6);
    host.toggleBold();
    selectRangeFocused(root, 4, 4);

    host.toggleBold();
    expect(lastState(states).bold.isActive).toBe(false);
    typeText(root, 'X');

    expect(host.getMarkdown()).toBe('ab**cd**X**ef**gh');
  });
});

describe('styles over line breaks', () => {
  // Review §2.4.3: select-all over two bold lines read as not bold (the line
  // breaks between them carry no range), so the first press re-bolded
  // everything with no visible change and only the second one unbolded.
  it('reads bold over bold lines and unbolds on the first press', () => {
    const { host, root, states } = mount();
    host.insertText('a\n\nb');
    selectRangeFocused(root, 0, 1);
    host.toggleBold();
    selectRangeFocused(root, 3, 4);
    host.toggleBold();
    expect(host.getMarkdown()).toBe('**a**\n\n**b**');

    selectRangeFocused(root, 0, 4);
    expect(lastState(states).bold.isActive).toBe(true);
    host.toggleBold();

    expect(host.getMarkdown()).toBe('a\n\nb');
  });
});

describe('state around a load', () => {
  // Review §2.2.4: a style toggled at the caret before a load must not carry
  // into the new document.
  it('drops a pending style when a new value loads', async () => {
    const { host, root } = mount();
    root.focus();
    host.toggleBold();

    await host.setValue('xyz');
    host.insertText('Q');

    expect(host.getMarkdown()).toBe('xyzQ');
  });

  // Review §2.2.6: a load reports no state, so focusing the editor is where a
  // toolbar first learns which block the caret sits in.
  it('reports the state at the caret when the loaded editor is focused', async () => {
    const { host, root, states } = mount();
    await host.importValue('# Title');
    expect(states).toEqual([]);

    root.focus();

    expect(states.at(-1)?.heading).toEqual({ isActive: true, level: 1 });
  });
});

// Review §2.1.4: Mod+B/I/U and the browser's formatting commands used to be
// cancelled and dropped.
describe('formatting shortcuts', () => {
  it('toggles bold, italic and underline from Mod+B/I/U', () => {
    const { host, root } = mount();
    host.insertText('one two six');
    selectRangeFocused(root, 0, 3);

    const bold = pressKey(root, 'b', { ctrlKey: true });
    expect(bold.defaultPrevented).toBe(true);
    selectRangeFocused(root, 4, 7);
    pressKey(root, 'i', { ctrlKey: true });
    selectRangeFocused(root, 8, 11);
    pressKey(root, 'U', { ctrlKey: true });

    expect(host.getMarkdown()).toBe('**one** *two* _six_');
  });

  it('leaves shifted and alt variants to the browser', () => {
    const { host, root } = mount();
    host.insertText('one');
    selectRangeFocused(root, 0, 3);

    expect(
      pressKey(root, 'b', { ctrlKey: true, shiftKey: true }).defaultPrevented
    ).toBe(false);
    expect(
      pressKey(root, 'b', { ctrlKey: true, altKey: true }).defaultPrevented
    ).toBe(false);
    expect(host.getMarkdown()).toBe('one');
  });

  it('runs the browser formatting commands as toggles', () => {
    const { host, root } = mount();
    host.insertText('one two');
    selectRangeFocused(root, 0, 3);
    sendInput(root, 'formatBold');
    selectRangeFocused(root, 4, 7);
    sendInput(root, 'formatStrikeThrough');

    expect(host.getMarkdown()).toBe('**one** ~~two~~');
  });
});

// Review §2.3.2, decided 2026-10-20: Enter at the start of a non-empty item
// opens an empty item above it, and the list stays one list.
describe('Enter at the start of a list item', () => {
  it.each([
    ['1. a\n2. b', 2, '1. a\n2. \n3. b'],
    ['- a\n- b', 2, '- a\n- \n- b'],
    ['1. a', 0, '1. \n2. a'],
  ])('%j at %i gives %j', async (markdown, caret, expected) => {
    const { host, root, selections } = mount();
    await host.setValue(markdown);
    selectRangeFocused(root, caret, caret);

    sendInput(root, 'insertParagraph');

    expect(host.getMarkdown()).toBe(expected);
    expect(selections.at(-1)).toEqual({ start: caret + 1, end: caret + 1 });
  });

  // Its markdown cannot say so - "  -" right under "- a" would read back as a
  // setext underline, so the serializer writes the empty item bare (review
  // §2.6.5) - but the model and the screen keep the nesting.
  it('keeps the depth of a nested item on the empty item above it', async () => {
    const { host, root } = mount();
    await host.setValue('- a\n  - b');
    selectRangeFocused(root, 2, 2);

    sendInput(root, 'insertParagraph');

    const lines = [...root.children] as HTMLElement[];
    expect(
      lines.map((line) => [line.dataset.block, line.dataset.depth])
    ).toEqual([
      ['unordered-list-item', '0'],
      ['unordered-list-item', '1'],
      ['unordered-list-item', '1'],
    ]);
  });

  it('still opens a plain line above a paragraph', async () => {
    const { host, root } = mount();
    await host.setValue('- a\n\nb');
    selectRangeFocused(root, 3, 3);

    sendInput(root, 'insertParagraph');

    expect(host.getMarkdown()).toBe('- a\n\n\nb');
  });
});

// Review §2.1.10, decided 2026-10-20: a newline that is not the Enter key -
// typed as text, pasted, inserted through the API - exits an empty item the
// way Enter does.
describe('a lone newline on an empty list item', () => {
  const emptyItem = async () => {
    const kit = mount();
    await kit.host.setValue('- a\n- ');
    selectRangeFocused(kit.root, 2, 2);
    return kit;
  };

  // Enter un-lists the empty item in place, leaving an empty line.
  const viaEnter = async () => {
    const { host, root } = await emptyItem();
    sendInput(root, 'insertParagraph');
    return host.getMarkdown();
  };

  it('exits the list when typed as text', async () => {
    const { host, root } = await emptyItem();
    dispatchTyping(root, '\n');
    expect(host.getMarkdown()).toBe(await viaEnter());
    expect(host.getMarkdown()).toBe('- a\n');
  });

  it('exits the list when pasted', async () => {
    const { host, root } = await emptyItem();
    sendClipboard(root, 'paste', '\r\n');
    expect(host.getMarkdown()).toBe(await viaEnter());
  });

  it('exits the list through insertText', async () => {
    const { host } = await emptyItem();
    host.insertText('\n');
    expect(host.getMarkdown()).toBe(await viaEnter());
  });

  // The browser performs the edit itself when an event escapes
  // `beforeinput` (a script's execCommand, some Android keyboards); the
  // host reads the line it added back from the DOM.
  it('exits the list when the browser inserted the line itself', async () => {
    const { host, root } = await emptyItem();
    const line = document.createElement('div');
    line.appendChild(document.createElement('br'));
    root.appendChild(line);
    root.dispatchEvent(
      new InputEvent('input', { inputType: 'insertParagraph', bubbles: true })
    );

    expect(host.getMarkdown()).toBe(await viaEnter());
    expect(root.children).toHaveLength(2);
  });
});
