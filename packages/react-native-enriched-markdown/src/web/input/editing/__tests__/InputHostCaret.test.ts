/**
 * @jest-environment jsdom
 */
import { diffEdit, readTextFromDom } from '../InputHost';
import {
  caretAt,
  domPointAt,
  lastState,
  mount,
  selectRangeFocused,
  sendInput,
  styledText,
  typeText,
} from './inputHostKit';

// The caret, the selection and the IME: the paths where the screen and the
// model can drift apart without either noticing.

afterEach(() => {
  document.body.replaceChildren();
});

function startComposition(root: HTMLElement): void {
  root.dispatchEvent(new Event('compositionstart', { bubbles: true }));
}

function endComposition(root: HTMLElement): void {
  root.dispatchEvent(new Event('compositionend', { bubbles: true }));
}

function placeDomCaret(node: Node, offset: number): void {
  document.getSelection()!.setBaseAndExtent(node, offset, node, offset);
}

function firstText(root: HTMLElement, line = 0): Text {
  const walker = document.createTreeWalker(
    root.children[line]!,
    NodeFilter.SHOW_TEXT
  );
  return walker.nextNode() as Text;
}

function lineTexts(root: HTMLElement): string[] {
  return [...root.childNodes].map((node) => node.textContent ?? '');
}

// The beforeinput a browser raises with its own target range, which jsdom
// cannot build: `getTargetRanges` is added by hand, over model offsets.
function sendInputWithTarget(
  root: HTMLElement,
  inputType: string,
  start: number,
  end: number,
  init: InputEventInit = {}
): void {
  const event = new InputEvent('beforeinput', {
    inputType,
    bubbles: true,
    cancelable: true,
    ...init,
  });
  const from = domPointAt(root, start);
  const to = domPointAt(root, end);
  Object.defineProperty(event, 'getTargetRanges', {
    value: () => [
      {
        startContainer: from.node,
        startOffset: from.offset,
        endContainer: to.node,
        endOffset: to.offset,
        collapsed: start === end,
      },
    ],
  });
  root.dispatchEvent(event);
}

describe('diffEdit', () => {
  it('takes the longest prefix when the caret is unknown', () => {
    expect(diffEdit('apple', 'aapple')).toEqual({
      editStart: 1,
      deletedText: '',
      insertedText: 'a',
    });
  });

  // Prefix and suffix overlap whenever the edit sits beside a copy of
  // itself; the caret says which copy is new.
  it('ends an ambiguous insert at the caret', () => {
    expect(diffEdit('apple', 'aapple', 1)).toEqual({
      editStart: 0,
      deletedText: '',
      insertedText: 'a',
    });
    expect(diffEdit('helo', 'hello', 3)).toEqual({
      editStart: 2,
      deletedText: '',
      insertedText: 'l',
    });
  });

  it('places an ambiguous delete at the caret', () => {
    expect(diffEdit('aab', 'ab', 0)).toEqual({
      editStart: 0,
      deletedText: 'a',
      insertedText: '',
    });
  });

  it('leaves an unambiguous edit alone whatever the caret says', () => {
    expect(diffEdit('abc', 'aXc', 3)).toEqual({
      editStart: 1,
      deletedText: 'b',
      insertedText: 'X',
    });
  });
});

describe('readTextFromDom', () => {
  it('places the caret across lines and stray text under the root', () => {
    const root = document.createElement('div');
    root.innerHTML = '<div><span>ab</span></div><div><br></div>';
    const stray = document.createTextNode('cd');
    root.appendChild(stray);
    root.appendChild(document.createElement('div')).textContent = 'ef';

    expect(readTextFromDom(root, { node: stray, offset: 1 })).toEqual({
      text: 'ab\ncd\nef',
      caret: 4,
    });
    expect(readTextFromDom(root, { node: root, offset: 4 }).caret).toBe(8);
  });
});

describe('composition read-back', () => {
  it('puts a composed character in front of its own copy at the caret', () => {
    const { root, host, selections } = mount();
    root.focus();
    typeText(root, 'apple');
    startComposition(root);
    const text = firstText(root);
    text.insertData(0, 'a');
    placeDomCaret(text, 1);
    endComposition(root);
    typeText(root, ' ');

    expect(host.value).toBe('a apple');
    expect(selections.at(-1)).toEqual({ start: 2, end: 2 });
  });

  it('keeps the caret after a letter committed beside its double', () => {
    const { root, host } = mount();
    root.focus();
    typeText(root, 'helo');
    caretAt(root, 2);
    document.dispatchEvent(new Event('selectionchange'));
    startComposition(root);
    const text = firstText(root);
    text.insertData(2, 'l');
    placeDomCaret(text, 3);
    endComposition(root);
    typeText(root, 'X');

    expect(host.value).toBe('helXlo');
  });

  // On Chrome Android a word stays composed until the space, so a Send
  // button that keeps focus reads the value mid-composition.
  it('includes the word being composed in the value', () => {
    const { root, host, texts, markdowns } = mount();
    root.focus();
    typeText(root, 'hi ');
    startComposition(root);
    const text = firstText(root);
    text.appendData('wor');
    placeDomCaret(text, 6);
    root.dispatchEvent(new InputEvent('input', { isComposing: true }));

    expect(host.value).toBe('hi wor');
    expect(host.getMarkdown()).toBe('hi wor');
    expect(texts.at(-1)).toBe('hi wor');
    expect(markdowns.at(-1)).toBe('hi wor');
    // The DOM stays the IME's: nothing was rendered over it.
    expect(firstText(root)).toBe(text);

    text.appendData('ld');
    placeDomCaret(text, 8);
    root.dispatchEvent(new InputEvent('input', { isComposing: true }));
    endComposition(root);
    expect(host.value).toBe('hi world');
    expect(root.textContent).toBe('hi world');
  });

  it('defers a style command until the composition ends', () => {
    const { root, host, states } = mount();
    root.focus();
    typeText(root, 'ab');
    startComposition(root);
    const text = firstText(root);
    host.toggleBold();
    text.appendData('c');
    placeDomCaret(text, 3);
    endComposition(root);

    // Not applied to the composed word, but pending for the next one.
    expect(styledText(root, 'strong')).toEqual([]);
    expect(lastState(states).bold.isActive).toBe(true);
    typeText(root, 'D');
    expect(styledText(root, 'strong')).toEqual(['D']);
  });

  it('does not move the DOM caret under the IME', () => {
    const { root, host } = mount();
    root.focus();
    typeText(root, 'hello');
    startComposition(root);
    const text = firstText(root);
    placeDomCaret(text, 5);
    host.setSelection(1, 1);

    expect(document.getSelection()!.anchorOffset).toBe(5);
    endComposition(root);
    expect(document.getSelection()!.anchorOffset).toBe(1);
  });

  it('hides the placeholder while text is being composed', () => {
    const { root } = mount();
    expect(root.hasAttribute('data-empty')).toBe(true);

    startComposition(root);
    expect(root.hasAttribute('data-empty')).toBe(false);
    endComposition(root);
    expect(root.hasAttribute('data-empty')).toBe(true);
  });
});

describe('IME leftovers', () => {
  it('rewrites a run the IME split, even when the text is unchanged', () => {
    const { root, host } = mount();
    root.focus();
    typeText(root, 'hello');
    startComposition(root);
    firstText(root).splitText(2);
    endComposition(root);

    const span = root.firstElementChild!.firstElementChild!;
    expect(span.childNodes).toHaveLength(1);
    expect(() => host.setSelection(4, 4)).not.toThrow();
    expect(host.caretRect()).not.toBeNull();
  });

  it('drops styling an IME left on a run', () => {
    const { root } = mount();
    root.focus();
    typeText(root, 'hello');
    startComposition(root);
    (root.firstElementChild!.firstElementChild as HTMLElement).style.color =
      'red';
    endComposition(root);

    expect(root.querySelector('[style]')).toBeNull();
  });

  it('reads stray text under the root once, not on every read-back', () => {
    const { root, host } = mount();
    root.focus();
    typeText(root, 'ab');
    startComposition(root);
    const stray = root.appendChild(document.createTextNode('か'));
    placeDomCaret(stray, 1);
    endComposition(root);
    startComposition(root);
    endComposition(root);

    expect(host.value).toBe('abか');
    expect(lineTexts(root)).toEqual(['abか']);
  });

  // The browser merges the lines of a selection a composition replaces.
  it('rebuilds lines the browser merged rather than removing the wrong one', () => {
    const { root, host } = mount();
    root.focus();
    typeText(root, 'abc');
    sendInput(root, 'insertParagraph');
    typeText(root, 'xyz');
    sendInput(root, 'insertParagraph');
    typeText(root, 'def');
    sendInput(root, 'insertParagraph');
    sendInput(root, 'insertParagraph');
    typeText(root, 'ghi');

    selectRangeFocused(root, 1, 5);
    startComposition(root);
    // "bc\nx" replaced by "X": the second line folds into the first.
    const first = firstText(root, 0);
    const second = root.children[1]!;
    first.data = 'aX' + (second.textContent ?? '').slice(1);
    second.remove();
    placeDomCaret(first, 2);
    endComposition(root);

    expect(host.value).toBe('aXyz\ndef\n\nghi');
    expect(lineTexts(root)).toEqual(host.value.split('\n'));
  });

  it('never patches into a stray <br> under the root', () => {
    const { root, host } = mount();
    root.focus();
    typeText(root, 'ab');
    root.appendChild(document.createElement('br'));
    caretAt(root, 2);
    sendInput(root, 'insertParagraph');
    typeText(root, 'c');

    expect(host.value).toBe('ab\nc');
    expect(root.querySelector('br > *')).toBeNull();
    expect(lineTexts(root)).toEqual(['ab', 'c']);
  });
});

describe('the escape hatch', () => {
  // Android Chrome performs some deletes whatever `preventDefault` says, and
  // an extension or `execCommand` writes without asking.
  it('reads back an edit that escaped beforeinput', () => {
    const { root, host, texts } = mount();
    root.focus();
    typeText(root, 'abc');
    const text = firstText(root);
    text.deleteData(2, 1);
    placeDomCaret(text, 2);
    root.dispatchEvent(
      new InputEvent('input', { inputType: 'deleteContentBackward' })
    );

    expect(host.value).toBe('ab');
    expect(texts.at(-1)).toBe('ab');
  });
});

describe('patching text', () => {
  // Assigning `nodeValue` collapses every live range in the node to 0, and
  // drops Blink's spellcheck markers with them.
  it('rewrites only the changed window of a text node', () => {
    const { root } = mount();
    root.focus();
    typeText(root, 'hello world');
    const text = firstText(root);
    const marker = document.createRange();
    marker.setStart(text, 8);
    caretAt(root, 0);
    document.dispatchEvent(new Event('selectionchange'));
    sendInput(root, 'deleteContentForward');

    expect(firstText(root)).toBe(text);
    expect(marker.startContainer).toBe(text);
    expect(marker.startOffset).toBe(7);
  });
});

describe('selection direction', () => {
  it('keeps a backward selection backward across a render', () => {
    const { root, host } = mount();
    root.focus();
    typeText(root, 'hello');
    const text = firstText(root);
    document.getSelection()!.setBaseAndExtent(text, 4, text, 1);
    document.dispatchEvent(new Event('selectionchange'));
    host.toggleBold();

    const selection = document.getSelection()!;
    expect(selection.anchorNode!.textContent).toBe('o');
    expect(selection.anchorOffset).toBe(0);
    expect(selection.focusNode!.textContent).toBe('ell');
    expect(selection.focusOffset).toBe(0);
  });
});

describe('select-all on an empty editor', () => {
  // Chrome selects the empty line's `<br>` and paints it as a range, while
  // the range it exposes is collapsed; only `type` tells them apart.
  it('replaces the phantom range with a caret', () => {
    const { root } = mount();
    root.focus();
    const selection = document.getSelection()!;
    const line = root.firstElementChild!;
    selection.setBaseAndExtent(line, 0, line, 0);
    const type = jest.spyOn(selection, 'type', 'get').mockReturnValue('Range');
    const write = jest.spyOn(selection, 'setBaseAndExtent');
    document.dispatchEvent(new Event('selectionchange'));

    expect(write).toHaveBeenCalledWith(line, 0, line, 0);
    type.mockRestore();
    write.mockRestore();
  });
});

describe('selection-only paths', () => {
  it('a caret toggle reports state but not markdown', () => {
    const { root, host, markdowns, states } = mount();
    typeText(root, 'ab');
    const emitted = markdowns.length;
    const stateCount = states.length;
    host.toggleBold();

    expect(markdowns).toHaveLength(emitted);
    expect(states.length).toBe(stateCount + 1);
  });
});

describe('links are atomic', () => {
  async function mountWithLink() {
    const mounted = mount();
    await mounted.host.setValue('[link](https://example.com) tail');
    mounted.root.focus();
    return mounted;
  }

  it('moves a caret placed inside a link to its end', async () => {
    const { host, selections } = await mountWithLink();
    host.setSelection(2, 2);

    expect(selections.at(-1)).toEqual({ start: 4, end: 4 });
  });

  it('widens a selection that cuts a link to cover it', async () => {
    const { host, selections } = await mountWithLink();
    host.setSelection(2, 6);

    expect(selections.at(-1)).toEqual({ start: 0, end: 6 });
  });

  it('snaps a caret the user put inside a link', async () => {
    const { root, host } = await mountWithLink();
    caretAt(root, 2);
    document.dispatchEvent(new Event('selectionchange'));
    typeText(root, 'W');

    expect(host.getMarkdown()).toBe('[link](https://example.com)W tail');
  });

  it('waits for a pointer selection to finish before snapping', async () => {
    const { root, selections } = await mountWithLink();
    // jsdom has no PointerEvent; the host reads only these two fields.
    const down = new Event('pointerdown', { bubbles: true });
    Object.defineProperties(down, {
      isPrimary: { value: true },
      button: { value: 0 },
    });
    root.dispatchEvent(down);
    caretAt(root, 2);
    document.dispatchEvent(new Event('selectionchange'));
    expect(selections.at(-1)).toEqual({ start: 2, end: 2 });

    document.dispatchEvent(new Event('pointerup'));
    expect(selections.at(-1)).toEqual({ start: 4, end: 4 });
  });

  it('Backspace at the end of a link deletes all of it', async () => {
    const { root, host } = await mountWithLink();
    caretAt(root, 4);
    sendInput(root, 'deleteContentBackward');

    expect(host.value).toBe(' tail');
    expect(host.getMarkdown()).toBe(' tail');
  });

  it('keeps a backward selection backward when widening it', async () => {
    const { root, selections } = await mountWithLink();
    const from = domPointAt(root, 7);
    const to = domPointAt(root, 2);
    document
      .getSelection()!
      .setBaseAndExtent(from.node, from.offset, to.node, to.offset);
    document.dispatchEvent(new Event('selectionchange'));

    expect(selections.at(-1)).toEqual({ start: 0, end: 7 });
    const selection = document.getSelection()!;
    const anchor = domPointAt(root, 7);
    const focus = domPointAt(root, 0);
    expect([selection.anchorNode, selection.anchorOffset]).toEqual([
      anchor.node,
      anchor.offset,
    ]);
    expect([selection.focusNode, selection.focusOffset]).toEqual([
      focus.node,
      focus.offset,
    ]);
  });
});

describe('target ranges', () => {
  it('a word delete takes the range the platform reports', () => {
    const { root, host } = mount();
    root.focus();
    typeText(root, 'hello.world');
    sendInputWithTarget(root, 'deleteWordBackward', 6, 11);

    expect(host.value).toBe('hello.');
  });

  it('a soft-line delete stops at the visual line, not the newline', () => {
    const { root, host } = mount();
    root.focus();
    typeText(root, 'one two three');
    sendInputWithTarget(root, 'deleteSoftLineBackward', 8, 13);

    expect(host.value).toBe('one two ');
  });

  it('falls back to its own scan without one', () => {
    const { root, host } = mount();
    root.focus();
    typeText(root, 'one two');
    sendInput(root, 'deleteWordBackward');

    expect(host.value).toBe('one ');
  });

  it('insertText replaces the range a correction addresses', () => {
    const { root, host } = mount();
    root.focus();
    typeText(root, 'teh cat');
    sendInputWithTarget(root, 'insertText', 0, 3, { data: 'the' });

    expect(host.value).toBe('the cat');
  });

  it('insertText reads the data transfer when data is null', () => {
    const { root, host } = mount();
    root.focus();
    const event = new InputEvent('beforeinput', {
      inputType: 'insertText',
      data: null,
      bubbles: true,
      cancelable: true,
    });
    Object.defineProperty(event, 'dataTransfer', {
      value: { getData: () => 'hi' },
    });
    root.dispatchEvent(event);

    expect(host.value).toBe('hi');
  });

  it('a replacement without target ranges replaces the selection', () => {
    const { root, host } = mount();
    typeText(root, 'teh cat');
    selectRangeFocused(root, 0, 3);
    root.dispatchEvent(
      new InputEvent('beforeinput', {
        inputType: 'insertReplacementText',
        data: 'the',
        bubbles: true,
        cancelable: true,
      })
    );

    expect(host.value).toBe('the cat');
  });
});

describe('live ranges', () => {
  // Every live Range is updated by each DOM mutation until it is collected,
  // so the keystroke and caret paths must not leave one behind per call.
  it('types, maps and measures the caret without a Range per call', () => {
    const { root, host } = mount();
    root.focus();
    typeText(root, 'hello world');
    const createRange = jest.spyOn(document, 'createRange');
    try {
      for (let i = 0; i < 20; i++) {
        caretAt(root, i % 11);
        document.dispatchEvent(new Event('selectionchange'));
        typeText(root, 'x');
        host.caretRect();
      }

      expect(createRange.mock.calls.length).toBeLessThanOrEqual(1);
    } finally {
      createRange.mockRestore();
    }
  });
});
