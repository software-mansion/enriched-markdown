/**
 * @jest-environment jsdom
 */
import { InputHost, type InputHostOptions } from '../InputHost';
import type { InputState } from '../InputState';

function mount(options?: InputHostOptions) {
  const root = document.createElement('div');
  document.body.appendChild(root);
  const texts: string[] = [];
  const states: InputState[] = [];
  const host = new InputHost(
    root,
    {
      onChangeText: (text) => texts.push(text),
      onChangeState: (state) => states.push(state),
    },
    options
  );
  return { root, host, texts, states };
}

function lastState(states: InputState[]): InputState {
  const state = states.at(-1);
  if (state === undefined) {
    throw new Error('no state was emitted');
  }
  return state;
}

function pressTab(root: HTMLElement, shiftKey = false): KeyboardEvent {
  const event = new KeyboardEvent('keydown', {
    key: 'Tab',
    shiftKey,
    bubbles: true,
    cancelable: true,
  });
  root.dispatchEvent(event);
  return event;
}

// The text of every run carrying `style`, so a typing attribute can be read
// back off the rendered DOM the way the user sees it.
function styledText(root: HTMLElement, style: string): string[] {
  return [...root.querySelectorAll(`.enrm-${style}`)].map(
    (run) => run.textContent ?? ''
  );
}

// The DOM point a model offset maps to, so the host reads a caret back out of
// the DOM the way a real one would. Walks the lines, then the runs within the
// line a styled range splits into several of.
function domPointAt(
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

function caretAt(root: HTMLElement, offset: number): void {
  const point = domPointAt(root, offset);
  document
    .getSelection()!
    .setBaseAndExtent(point.node, point.offset, point.node, point.offset);
}

function selectRange(root: HTMLElement, start: number, end: number): void {
  const from = domPointAt(root, start);
  const to = domPointAt(root, end);
  document
    .getSelection()!
    .setBaseAndExtent(from.node, from.offset, to.node, to.offset);
}

// A toolbar command reads the model selection, which in a browser arrives
// through `selectionchange` while the editor has focus. jsdom dispatches
// neither, so both halves are done by hand.
function selectRangeFocused(
  root: HTMLElement,
  start: number,
  end: number
): void {
  root.focus();
  selectRange(root, start, end);
  document.dispatchEvent(new Event('selectionchange'));
}

function typeText(root: HTMLElement, data: string): void {
  root.dispatchEvent(
    new InputEvent('beforeinput', {
      inputType: 'insertText',
      data,
      bubbles: true,
      cancelable: true,
    })
  );
}

function sendInput(root: HTMLElement, inputType: string): void {
  root.dispatchEvent(
    new InputEvent('beforeinput', {
      inputType,
      bubbles: true,
      cancelable: true,
    })
  );
}

function sendClipboard(
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

function compose(root: HTMLElement, composed: string): void {
  root.dispatchEvent(new Event('compositionstart', { bubbles: true }));
  // What the IME does while the model stands back: it writes its result
  // straight into the text node the renderer put there.
  const text = root.firstElementChild!.firstChild!.firstChild as Text;
  text.nodeValue = composed;
  root.dispatchEvent(new Event('compositionend', { bubbles: true }));
}

describe('InputHost', () => {
  afterEach(() => {
    document.body.replaceChildren();
  });

  it('inserts typed text at the caret and reports it', () => {
    const { root, host, texts } = mount();
    typeText(root, 'ab');
    caretAt(root, 1);
    typeText(root, 'X');

    expect(host.value).toBe('aXb');
    expect(texts).toEqual(['ab', 'aXb']);
  });

  it('cancels every input type it does not handle', () => {
    const { root, host } = mount();
    typeText(root, 'ab');

    for (const inputType of ['formatBold', 'historyUndo', 'insertFromDrop']) {
      const event = new InputEvent('beforeinput', {
        inputType,
        bubbles: true,
        cancelable: true,
      });
      root.dispatchEvent(event);
      expect(event.defaultPrevented).toBe(true);
    }
    expect(host.value).toBe('ab');
  });

  describe('deleting', () => {
    it('removes one grapheme cluster, not one code point', () => {
      const { root, host } = mount();
      typeText(root, 'a\u{1F468}‍\u{1F469}‍\u{1F467}');
      sendInput(root, 'deleteContentBackward');

      // One press, one visible character: no dangling ZWJ left in the buffer.
      expect(host.value).toBe('a');
    });

    it('removes the word before the caret', () => {
      const { root, host } = mount();
      typeText(root, 'hello brave world');
      sendInput(root, 'deleteWordBackward');

      expect(host.value).toBe('hello brave ');
    });

    it('joins the lines when a word delete has nowhere to go', () => {
      const { root, host } = mount();
      sendClipboard(root, 'paste', 'ab\ncd');
      caretAt(root, 3);
      sendInput(root, 'deleteWordBackward');

      expect(host.value).toBe('abcd');
    });

    it('removes to the line start', () => {
      const { root, host } = mount();
      typeText(root, 'hello world');
      sendInput(root, 'deleteSoftLineBackward');

      expect(host.value).toBe('');
    });

    it('removes the selection rather than one character', () => {
      const { root, host } = mount();
      typeText(root, 'abcdef');
      selectRange(root, 1, 4);
      sendInput(root, 'deleteContentBackward');

      expect(host.value).toBe('aef');
    });
  });

  describe('the clipboard', () => {
    // The UA writes the clipboard itself and then performs the deletion,
    // whose beforeinput the host cancels. Without taking over both halves a
    // cut copies the text and leaves it in place.
    it('cut writes the selection to the clipboard and removes it', () => {
      const { root, host } = mount();
      typeText(root, 'hello');
      selectRange(root, 0, 5);
      const written = sendClipboard(root, 'cut');

      expect(written.get('text/plain')).toBe('hello');
      expect(host.value).toBe('');
    });

    it('cut with no selection leaves the buffer alone', () => {
      const { root, host } = mount();
      typeText(root, 'hello');
      caretAt(root, 2);
      const written = sendClipboard(root, 'cut');

      expect(written.size).toBe(0);
      expect(host.value).toBe('hello');
    });

    it('paste inserts plain text and normalizes its line endings', () => {
      const { root, host } = mount();
      typeText(root, 'ab');
      caretAt(root, 1);
      sendClipboard(root, 'paste', 'X\r\nY\rZ');

      expect(host.value).toBe('aX\nY\nZb');
    });

    it('paste replaces the selection', () => {
      const { root, host } = mount();
      typeText(root, 'abcdef');
      selectRange(root, 1, 5);
      sendClipboard(root, 'paste', 'X');

      expect(host.value).toBe('aXf');
    });
  });

  describe('composition', () => {
    // The browser owns the DOM through a composition, so the composed text
    // lands without the model seeing it. Left unread, the model and the DOM
    // diverge for good: the text stays on screen while `value` omits it.
    it('reads composed text back out of the DOM', () => {
      const { root, host, texts } = mount();
      typeText(root, 'ab');
      compose(root, 'abko');

      expect(host.value).toBe('abko');
      expect(texts.at(-1)).toBe('abko');
      expect(root.textContent).toBe('abko');
    });

    it('reads back a composition that replaced text', () => {
      const { root, host } = mount();
      typeText(root, 'cafe');
      compose(root, 'café');

      expect(host.value).toBe('café');
    });

    it('stands back while a composition is running', () => {
      const { root, host } = mount();
      typeText(root, 'ab');
      root.dispatchEvent(new Event('compositionstart', { bubbles: true }));
      typeText(root, 'X');

      expect(host.value).toBe('ab');
    });

    // A composition abandoned by a blur does not always fire compositionend,
    // and a latched flag makes the editor read-only for good.
    it('a blur ends a composition rather than wedging the editor', () => {
      const { root, host } = mount();
      typeText(root, 'ab');
      root.dispatchEvent(new Event('compositionstart', { bubbles: true }));
      root.dispatchEvent(new Event('blur', { bubbles: false }));
      caretAt(root, 2);
      typeText(root, 'c');

      expect(host.value).toBe('abc');
    });
  });

  describe('enter', () => {
    it.each(['insertParagraph', 'insertLineBreak'])(
      'inserts a line break for %s',
      (inputType) => {
        const { root, host } = mount();
        typeText(root, 'ab');
        sendInput(root, inputType);
        typeText(root, 'c');

        expect(host.value).toBe('ab\nc');
      }
    );

    it('splits the line at the caret', () => {
      const { root, host } = mount();
      typeText(root, 'abcd');
      caretAt(root, 2);
      sendInput(root, 'insertParagraph');

      expect(host.value).toBe('ab\ncd');
    });

    it('replaces the selection with the line break', () => {
      const { root, host } = mount();
      typeText(root, 'abcdef');
      selectRange(root, 2, 4);
      sendInput(root, 'insertParagraph');

      expect(host.value).toBe('ab\nef');
    });

    it('continues a list item onto the new line', () => {
      const { root, host, states } = mount();
      typeText(root, 'a');
      host.toggleUnorderedList();
      sendInput(root, 'insertParagraph');
      typeText(root, 'b');

      expect(host.value).toBe('a\nb');
      expect(lastState(states).unorderedList).toEqual({
        isActive: true,
        depth: 0,
      });
    });

    it('keeps both halves in the list when an item is split', () => {
      const { root, host, states } = mount();
      typeText(root, 'ab');
      host.toggleUnorderedList();
      caretAt(root, 1);
      sendInput(root, 'insertParagraph');

      expect(host.value).toBe('a\nb');
      // The caret lands on the second half, which stayed an item.
      expect(lastState(states).unorderedList.isActive).toBe(true);
    });

    it('carries the depth onto the continued item', () => {
      const { root, host, states } = mount();
      typeText(root, 'a');
      host.toggleUnorderedList();
      sendInput(root, 'insertParagraph');
      typeText(root, 'b');
      pressTab(root);
      sendInput(root, 'insertParagraph');
      typeText(root, 'c');

      expect(host.value).toBe('a\nb\nc');
      expect(lastState(states).unorderedList).toEqual({
        isActive: true,
        depth: 1,
      });
    });

    // The way out of a list without reaching for the toolbar: Enter on an
    // item with nothing in it un-lists that item rather than adding a line.
    it('exits an empty list item instead of inserting a line', () => {
      const { root, host, states } = mount();
      typeText(root, 'a');
      host.toggleUnorderedList();
      sendInput(root, 'insertParagraph');
      expect(host.value).toBe('a\n');

      sendInput(root, 'insertParagraph');

      expect(host.value).toBe('a\n');
      expect(lastState(states).unorderedList.isActive).toBe(false);
    });

    it('does not continue a heading', () => {
      const { root, host, states } = mount();
      typeText(root, 'a');
      host.toggleHeading(1);
      sendInput(root, 'insertParagraph');
      typeText(root, 'b');

      expect(host.value).toBe('a\nb');
      expect(lastState(states).heading.isActive).toBe(false);
    });
  });

  describe('tab', () => {
    // Tab never reaches beforeinput, so the editor has to claim the key or
    // the browser moves focus out of it.
    it('never leaves the editor', () => {
      const { root } = mount();
      typeText(root, 'a');

      expect(pressTab(root).defaultPrevented).toBe(true);
      expect(pressTab(root, true).defaultPrevented).toBe(true);
    });

    it('starts a list on a plain paragraph', () => {
      const { root, states } = mount();
      typeText(root, 'a');
      pressTab(root);

      expect(lastState(states).unorderedList).toEqual({
        isActive: true,
        depth: 0,
      });
    });

    it('indents and outdents an item', () => {
      const { root, host, states } = mount();
      typeText(root, 'a');
      host.toggleUnorderedList();
      sendInput(root, 'insertParagraph');
      typeText(root, 'b');

      pressTab(root);
      expect(lastState(states).unorderedList.depth).toBe(1);

      pressTab(root, true);
      expect(lastState(states).unorderedList.depth).toBe(0);
    });

    it('outdenting at depth 0 leaves the list', () => {
      const { root, host, states } = mount();
      typeText(root, 'a');
      host.toggleUnorderedList();

      pressTab(root, true);

      expect(lastState(states).unorderedList.isActive).toBe(false);
    });

    it('leaves a heading alone', () => {
      const { root, host, states } = mount();
      typeText(root, 'a');
      host.toggleHeading(2);

      pressTab(root);

      expect(lastState(states).heading).toEqual({ isActive: true, level: 2 });
      expect(lastState(states).unorderedList.isActive).toBe(false);
    });

    // The IME owns Tab while a composition is open; claiming it there would
    // take the key away from the candidate list.
    it('stands back during a composition', () => {
      const { root, host, states } = mount();
      typeText(root, 'a');
      host.toggleUnorderedList();
      root.dispatchEvent(new Event('compositionstart', { bubbles: true }));

      expect(pressTab(root).defaultPrevented).toBe(false);
      expect(lastState(states).unorderedList.depth).toBe(0);
    });

    it('ignores every other key', () => {
      const { root } = mount();
      const event = new KeyboardEvent('keydown', {
        key: 'a',
        bubbles: true,
        cancelable: true,
      });
      root.dispatchEvent(event);

      expect(event.defaultPrevented).toBe(false);
    });
  });

  // Backspace at the start of an item walks it out of the list one step at a
  // time before it is allowed to merge with the line above, so a press never
  // silently destroys the line break.
  describe('backspace at the start of a list item', () => {
    function twoItemsWithCaretOnTheSecond() {
      const mounted = mount();
      const { root, host } = mounted;
      typeText(root, 'a');
      host.toggleUnorderedList();
      sendInput(root, 'insertParagraph');
      typeText(root, 'b');
      pressTab(root);
      caretAt(root, 2);
      return mounted;
    }

    it('outdents first', () => {
      const { root, host, states } = twoItemsWithCaretOnTheSecond();

      sendInput(root, 'deleteContentBackward');

      expect(host.value).toBe('a\nb');
      expect(lastState(states).unorderedList).toEqual({
        isActive: true,
        depth: 0,
      });
    });

    it('un-lists at depth 0', () => {
      const { root, host, states } = twoItemsWithCaretOnTheSecond();

      sendInput(root, 'deleteContentBackward');
      caretAt(root, 2);
      sendInput(root, 'deleteContentBackward');

      expect(host.value).toBe('a\nb');
      expect(lastState(states).unorderedList.isActive).toBe(false);
    });

    it('merges the lines once out of the list', () => {
      const { root, host } = twoItemsWithCaretOnTheSecond();

      sendInput(root, 'deleteContentBackward');
      caretAt(root, 2);
      sendInput(root, 'deleteContentBackward');
      caretAt(root, 2);
      sendInput(root, 'deleteContentBackward');

      expect(host.value).toBe('ab');
    });

    it('deletes a character normally when the caret is not at the start', () => {
      const { root, host, states } = twoItemsWithCaretOnTheSecond();
      caretAt(root, 3);

      sendInput(root, 'deleteContentBackward');

      expect(host.value).toBe('a\n');
      expect(lastState(states).unorderedList.depth).toBe(1);
    });

    it('removes a selection rather than outdenting', () => {
      const { root, host } = twoItemsWithCaretOnTheSecond();
      selectRange(root, 2, 3);

      sendInput(root, 'deleteContentBackward');

      expect(host.value).toBe('a\n');
    });
  });

  describe('inline style commands', () => {
    it('styles the characters typed after a caret toggle', () => {
      const { root, host } = mount();
      typeText(root, 'ab');
      host.toggleBold();
      typeText(root, 'cd');

      expect(host.value).toBe('abcd');
      expect(styledText(root, 'strong')).toEqual(['cd']);
    });

    it('styles the selection directly', () => {
      const { root, host, states } = mount();
      typeText(root, 'abcd');
      selectRangeFocused(root, 1, 3);
      host.toggleBold();

      expect(styledText(root, 'strong')).toEqual(['bc']);
      expect(lastState(states).bold.isActive).toBe(true);
    });

    it('carries a pending removal into the next keystroke', () => {
      const { root, host } = mount();
      typeText(root, 'ab');
      host.toggleBold();
      typeText(root, 'cd');
      host.toggleBold();
      typeText(root, 'ef');

      expect(styledText(root, 'strong')).toEqual(['cd']);
    });

    it.each([
      ['toggleItalic', 'em'],
      ['toggleUnderline', 'underline'],
      ['toggleStrikethrough', 'strikethrough'],
      ['toggleSpoiler', 'spoiler'],
    ] as const)('%s styles the selection', (method, style) => {
      const { root, host } = mount();
      typeText(root, 'abcd');
      selectRangeFocused(root, 1, 3);
      host[method]();

      expect(styledText(root, style)).toEqual(['bc']);
    });

    // A caret moved by the user abandons the toggle they never used; a caret
    // moved by their own keystroke must not, or the pending style would be
    // dropped before the character it was meant for arrives. The two are told
    // apart by the post-edit grace period, so these drive the clock.
    describe('a pending toggle across a selection change', () => {
      let now: jest.SpyInstance<number, []>;

      beforeEach(() => {
        now = jest.spyOn(performance, 'now').mockReturnValue(0);
      });

      afterEach(() => {
        now.mockRestore();
      });

      it('survives a selection change inside the grace period', () => {
        const { root, host } = mount();
        typeText(root, 'abcd');
        host.toggleBold();
        selectRangeFocused(root, 2, 2);
        typeText(root, 'X');

        expect(styledText(root, 'strong')).toEqual(['X']);
      });

      it('is abandoned by a selection change after it', () => {
        const { root, host } = mount();
        typeText(root, 'abcd');
        host.toggleBold();
        now.mockReturnValue(1000);
        selectRangeFocused(root, 2, 2);
        typeText(root, 'X');

        expect(styledText(root, 'strong')).toEqual([]);
      });

      it('inherits the run the caret lands in', () => {
        const { root, host } = mount();
        typeText(root, 'abcd');
        selectRangeFocused(root, 1, 3);
        host.toggleBold();
        now.mockReturnValue(1000);
        selectRangeFocused(root, 3, 3);
        typeText(root, 'X');

        expect(styledText(root, 'strong')).toEqual(['bcX']);
      });
    });

    it('reports the style in the state it emits', () => {
      const { root, host, states } = mount();
      typeText(root, 'ab');
      host.toggleBold();

      expect(lastState(states).bold.isActive).toBe(true);
    });
  });

  describe('the state event', () => {
    it('reports a block command', () => {
      const { root, host, states } = mount();
      typeText(root, 'a');
      host.toggleHeading(3);

      expect(lastState(states).heading).toEqual({ isActive: true, level: 3 });

      host.toggleHeading(3);
      expect(lastState(states).heading).toEqual({ isActive: false, level: 0 });
    });

    it('reports a list command', () => {
      const { root, host, states } = mount();
      typeText(root, 'a');

      host.toggleOrderedList();
      expect(lastState(states).orderedList.isActive).toBe(true);

      host.toggleUnorderedList();
      expect(lastState(states).orderedList.isActive).toBe(false);
      expect(lastState(states).unorderedList.isActive).toBe(true);
    });

    // Every keystroke builds a state, so without the equality check a
    // consumer would re-render on each character for a state that never
    // changed.
    it('fires only when the state actually changes', () => {
      const { root, states } = mount();
      typeText(root, 'a');
      typeText(root, 'b');
      typeText(root, 'c');

      expect(states).toHaveLength(1);
    });

    it('fires again once the state differs', () => {
      const { root, host, states } = mount();
      typeText(root, 'a');
      const before = states.length;

      host.toggleBold();

      expect(states.length).toBe(before + 1);
    });

    it('stays quiet through an import', async () => {
      const { host, states } = mount();
      await host.importValue('# hello');

      expect(states).toEqual([]);
    });
  });

  describe('the host element', () => {
    it('leaves spellcheck to the browser unless asked', () => {
      const { root } = mount();
      expect(root.hasAttribute('spellcheck')).toBe(false);
    });

    it('turns spellcheck off on request', () => {
      const { root } = mount({ spellCheck: false });
      expect(root.getAttribute('spellcheck')).toBe('false');
    });

    it("keeps a consumer's own role", () => {
      const root = document.createElement('div');
      root.setAttribute('role', 'presentation');
      document.body.appendChild(root);
      const host = new InputHost(root);

      expect(root.getAttribute('role')).toBe('presentation');
      // Not ours to set, so not ours to remove either.
      host.destroy();
      expect(root.getAttribute('role')).toBe('presentation');
    });

    it('defaults role and aria-multiline when the node has none', () => {
      const { root } = mount();
      expect(root.getAttribute('role')).toBe('textbox');
      expect(root.getAttribute('aria-multiline')).toBe('true');
    });

    // A consumer that owns the node and keeps it would otherwise hand the
    // user a contentEditable with no model behind it.
    it('destroy leaves nothing editable behind', () => {
      const { root, host } = mount({ spellCheck: false });
      typeText(root, 'ab');
      host.destroy();

      expect(root.hasAttribute('contenteditable')).toBe(false);
      expect(root.hasAttribute('spellcheck')).toBe(false);
      expect(root.hasAttribute('data-gramm')).toBe(false);
      expect(root.childNodes).toHaveLength(0);
      expect(root.className).toBe('');
    });

    it('destroy stops routing events', () => {
      const { root, host } = mount();
      typeText(root, 'ab');
      host.destroy();
      typeText(root, 'c');

      expect(host.value).toBe('ab');
    });

    it('destroy twice is a no-op', () => {
      const { root, host } = mount();
      host.destroy();
      expect(() => host.destroy()).not.toThrow();
      expect(root.hasAttribute('contenteditable')).toBe(false);
    });
  });
});
