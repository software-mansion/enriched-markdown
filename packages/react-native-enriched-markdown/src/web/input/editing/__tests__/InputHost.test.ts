/**
 * @jest-environment jsdom
 */
import { InputHost, type InputHostOptions } from '../InputHost';

function mount(options?: InputHostOptions) {
  const root = document.createElement('div');
  document.body.appendChild(root);
  const texts: string[] = [];
  const host = new InputHost(
    root,
    { onChangeText: (text) => texts.push(text) },
    options
  );
  return { root, host, texts };
}

function caretAt(root: HTMLElement, offset: number): void {
  // Walk the rendered lines to the text node holding `offset`, so the host
  // reads the caret back out of the DOM the way a real one would.
  let remaining = offset;
  for (const line of root.children) {
    const length = (line.textContent ?? '').length;
    if (remaining <= length) {
      const text = line.firstElementChild?.firstChild;
      const selection = document.getSelection()!;
      if (text == null) {
        selection.setBaseAndExtent(line, 0, line, 0);
      } else {
        selection.setBaseAndExtent(text, remaining, text, remaining);
      }
      return;
    }
    remaining -= length + 1;
  }
}

function selectRange(root: HTMLElement, start: number, end: number): void {
  const nodeAt = (offset: number) => {
    let remaining = offset;
    for (const line of root.children) {
      const length = (line.textContent ?? '').length;
      if (remaining <= length) {
        return { node: line.firstElementChild?.firstChild ?? line, remaining };
      }
      remaining -= length + 1;
    }
    return { node: root, remaining: 0 };
  };
  const from = nodeAt(start);
  const to = nodeAt(end);
  document
    .getSelection()!
    .setBaseAndExtent(from.node, from.remaining, to.node, to.remaining);
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
      // Enter is not wired yet, so the second line arrives by paste.
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
