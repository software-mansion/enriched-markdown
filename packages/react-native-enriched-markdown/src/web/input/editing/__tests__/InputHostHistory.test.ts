/**
 * @jest-environment jsdom
 */
import {
  caretAt,
  compose,
  lastState,
  mount,
  pressKey,
  pressTab,
  selectRangeFocused,
  sendClipboard,
  sendInput,
  styledText,
  typeText,
  type MountedHost,
  pasteText,
} from './inputHostKit';
import type { RangeBounds } from '../../model/rangeBounds';

interface Expected {
  value: string;
  markdown: string;
  selection: RangeBounds;
  // The DOM as it was in this state; a fresh import of `markdown` otherwise.
  html?: string;
}

// What a document looks like from every side: the buffer, its markdown, the
// caret reported, and the DOM - which has to be what a fresh import of that
// markdown renders (or what the editor showed in that state), not merely hold
// the same text.
async function expectDocument(
  { root, host, selections }: MountedHost,
  expected: Expected
): Promise<void> {
  expect(host.value).toBe(expected.value);
  expect(host.getMarkdown()).toBe(expected.markdown);
  expect(selections.at(-1)).toEqual(expected.selection);
  if (expected.html !== undefined) {
    expect(root.innerHTML).toBe(expected.html);
    return;
  }
  const fresh = mount();
  await fresh.host.importValue(expected.markdown);
  // A run that lost its last style keeps an empty class attribute.
  expect(root.innerHTML.replaceAll(' class=""', '')).toBe(fresh.root.innerHTML);
  fresh.root.remove();
}

function current({ root, host, selections }: MountedHost): Expected {
  return {
    value: host.value,
    markdown: host.getMarkdown(),
    selection: selections.at(-1)!,
    html: root.innerHTML,
  };
}

// Undoes back to `before`, redoes forward to `after`, and undoes once more,
// so a redo that left anything behind would show on the second undo.
async function expectUndoRedo(
  mounted: MountedHost,
  before: Expected,
  after: Expected
): Promise<void> {
  await expectDocument(mounted, after);
  mounted.host.undo();
  await expectDocument(mounted, before);
  mounted.host.redo();
  await expectDocument(mounted, after);
  mounted.host.undo();
  await expectDocument(mounted, before);
}

function caret(offset: number): RangeBounds {
  return { start: offset, end: offset };
}

const EMPTY: Expected = { value: '', markdown: '', selection: caret(0) };

function mountFocused(): MountedHost {
  const mounted = mount();
  mounted.root.focus();
  return mounted;
}

afterEach(() => {
  document.body.replaceChildren();
  jest.restoreAllMocks();
});

describe('InputHost history', () => {
  it('undoes typing back to an empty editor', async () => {
    const mounted = mountFocused();
    typeText(mounted.root, 'hello');

    await expectUndoRedo(mounted, EMPTY, {
      value: 'hello',
      markdown: 'hello',
      selection: caret(5),
    });
  });

  it('undoes a run of backspaces as one step', async () => {
    const mounted = mountFocused();
    const { root } = mounted;
    typeText(root, 'hello');
    caretAt(root, 3);
    document.dispatchEvent(new Event('selectionchange'));
    sendInput(root, 'deleteContentBackward');
    sendInput(root, 'deleteContentBackward');

    await expectUndoRedo(
      mounted,
      { value: 'hello', markdown: 'hello', selection: caret(3) },
      { value: 'hlo', markdown: 'hlo', selection: caret(1) }
    );
  });

  it('undoes a list continuation on Enter', async () => {
    const mounted = mountFocused();
    const { root, host } = mounted;
    typeText(root, 'a');
    host.toggleUnorderedList();
    const before = current(mounted);
    sendInput(root, 'insertParagraph');
    // An emptied last item does not survive a markdown round trip, so the DOM
    // is compared against what the editor showed instead.
    expect(host.value).toBe('a\n');
    expect(lastState(mounted.states).unorderedList.isActive).toBe(true);

    await expectUndoRedo(mounted, before, current(mounted));
  });

  it('undoes Enter on an empty list item, which ends the list', async () => {
    const mounted = mountFocused();
    const { root, host } = mounted;
    typeText(root, 'a');
    host.toggleUnorderedList();
    sendInput(root, 'insertParagraph');
    sendInput(root, 'insertParagraph');

    expect(host.value).toBe('a\n');
    expect(lastState(mounted.states).unorderedList.isActive).toBe(false);
    host.undo();
    expect(lastState(mounted.states).unorderedList.isActive).toBe(true);
    host.redo();
    expect(lastState(mounted.states).unorderedList.isActive).toBe(false);
  });

  it('undoes a Tab indent', async () => {
    const mounted = mountFocused();
    const { root, host } = mounted;
    typeText(root, 'a');
    host.toggleUnorderedList();
    sendInput(root, 'insertParagraph');
    typeText(root, 'b');
    const before = host.getMarkdown();
    pressTab(root);
    expect(lastState(mounted.states).unorderedList.depth).toBe(1);

    host.undo();
    expect(host.getMarkdown()).toBe(before);
    expect(lastState(mounted.states).unorderedList.depth).toBe(0);
    host.redo();
    expect(lastState(mounted.states).unorderedList.depth).toBe(1);
  });

  it('records nothing for a Tab that changes nothing', () => {
    const mounted = mountFocused();
    const { root, host } = mounted;
    typeText(root, 'a');
    host.toggleUnorderedList();
    host.undo();
    host.toggleUnorderedList();
    // The first item cannot indent past the list it starts.
    pressTab(root);
    host.undo();

    expect(host.getMarkdown()).toBe('a');
  });

  it('undoes bold on a selection', async () => {
    const mounted = mountFocused();
    const { root, host } = mounted;
    typeText(root, 'hello');
    selectRangeFocused(root, 0, 5);
    host.toggleBold();

    await expectUndoRedo(
      mounted,
      { value: 'hello', markdown: 'hello', selection: { start: 0, end: 5 } },
      {
        value: 'hello',
        markdown: '**hello**',
        selection: { start: 0, end: 5 },
      }
    );
  });

  it('undoes text typed with a caret bold, and re-seeds the caret styles', async () => {
    const mounted = mountFocused();
    const { root, host, states } = mounted;
    typeText(root, 'ab');
    host.toggleBold();
    typeText(root, '12');
    expect(styledText(root, 'strong')).toEqual(['12']);

    host.undo();
    await expectDocument(mounted, {
      value: 'ab',
      markdown: 'ab',
      selection: caret(2),
    });
    // The caret's styles come from where it now sits, not the bold it
    // pended before.
    expect(lastState(states).bold.isActive).toBe(false);
    typeText(root, 'c');
    expect(styledText(root, 'strong')).toEqual([]);
  });

  it('undoes a heading', async () => {
    const mounted = mountFocused();
    const { root, host } = mounted;
    typeText(root, 'title');
    host.toggleHeading(2);

    await expectUndoRedo(
      mounted,
      { value: 'title', markdown: 'title', selection: caret(5) },
      { value: 'title', markdown: '## title', selection: caret(5) }
    );
  });

  it('undoes an unordered list', async () => {
    const mounted = mountFocused();
    const { root, host } = mounted;
    typeText(root, 'item');
    host.toggleUnorderedList();

    await expectUndoRedo(
      mounted,
      { value: 'item', markdown: 'item', selection: caret(4) },
      { value: 'item', markdown: '- item', selection: caret(4) }
    );
  });

  it('undoes a paste as one step of its own', async () => {
    const mounted = mountFocused();
    const { root } = mounted;
    typeText(root, 'a');
    await pasteText(root, 'bc\nd');

    await expectUndoRedo(
      mounted,
      { value: 'a', markdown: 'a', selection: caret(1) },
      { value: 'abc\nd', markdown: 'abc\nd', selection: caret(5) }
    );
  });

  it('undoes a cut, putting the selection back', async () => {
    const mounted = mountFocused();
    const { root } = mounted;
    typeText(root, 'hello');
    selectRangeFocused(root, 1, 4);
    sendClipboard(root, 'cut');

    await expectUndoRedo(
      mounted,
      { value: 'hello', markdown: 'hello', selection: { start: 1, end: 4 } },
      { value: 'ho', markdown: 'ho', selection: caret(1) }
    );
  });

  it('undoes a composition as one step', async () => {
    const mounted = mountFocused();
    const { root, host } = mounted;
    typeText(root, 'ab');
    caretAt(root, 2);
    compose(root, 'abかな');
    expect(host.value).toBe('abかな');

    host.undo();
    expect(host.value).toBe('ab');
    host.redo();
    expect(host.value).toBe('abかな');
  });

  it('undoes the fast path, whose report waits for the settle', () => {
    const mounted = mountFocused();
    const { root, host, histories } = mounted;
    typeText(root, 'a');

    // The browser made the edit itself, and `input` settled it.
    expect(histories).toEqual([{ canUndo: true, canRedo: false }]);
    typeText(root, 'b');
    host.undo();
    expect(host.value).toBe('');
  });

  it('restores a link a whole-link Backspace removed', async () => {
    const mounted = mountFocused();
    const { root, host } = mounted;
    await host.importValue('see [docs](https://x.dev)');
    root.focus();
    caretAt(root, 8);
    document.dispatchEvent(new Event('selectionchange'));
    sendInput(root, 'deleteContentBackward');
    expect(host.value).toBe('see ');

    host.undo();
    expect(host.value).toBe('see docs');
    expect(host.getMarkdown()).toBe('see [docs](https://x.dev)');
  });

  describe('the events a step reports', () => {
    it('reports no text or selection change for a formatting-only step', () => {
      const mounted = mount();
      const { host, root, texts, selections, markdowns, states } = mounted;
      root.focus();
      typeText(root, 'hello world');
      selectRangeFocused(root, 0, 5);
      host.toggleBold();
      const before = { texts: texts.length, selections: selections.length };

      host.undo();
      expect(texts).toHaveLength(before.texts);
      expect(selections).toHaveLength(before.selections);
      expect(markdowns.at(-1)).toBe('hello world');
      expect(lastState(states).bold.isActive).toBe(false);

      host.redo();
      expect(texts).toHaveLength(before.texts);
      expect(selections).toHaveLength(before.selections);
      expect(markdowns.at(-1)).toBe('**hello** world');
      expect(lastState(states).bold.isActive).toBe(true);
    });

    it('still reports the text and selection when a step changes them', () => {
      const { host, root, texts, selections } = mount();
      root.focus();
      typeText(root, 'ab');
      const before = { texts: texts.length, selections: selections.length };

      host.undo();

      expect(texts.slice(before.texts)).toEqual(['']);
      expect(selections.slice(before.selections)).toEqual([
        { start: 0, end: 0 },
      ]);
    });
  });

  describe('entry points', () => {
    it('takes historyUndo and historyRedo from beforeinput', () => {
      jest.useFakeTimers();
      const { root, host } = mountFocused();
      typeText(root, 'ab');

      sendInput(root, 'historyUndo');
      expect(host.value).toBe('');
      jest.runAllTimers();
      sendInput(root, 'historyRedo');
      expect(host.value).toBe('ab');
      jest.useRealTimers();
    });

    // WebKit raises one per entry on its own stack for a single Undo once a
    // scripted render has split that stack: Edit menu Undo after typing,
    // Enter, typing undid both lines.
    it('takes one history input per task', () => {
      jest.useFakeTimers();
      const { root, host } = mountFocused();
      typeText(root, 'ab');
      sendInput(root, 'insertParagraph');
      typeText(root, 'cd');

      sendInput(root, 'historyUndo');
      sendInput(root, 'historyUndo');
      expect(host.value).toBe('ab\n');
      jest.runAllTimers();
      sendInput(root, 'historyUndo');
      expect(host.value).toBe('ab');
      jest.useRealTimers();
    });

    it('takes Ctrl+Z, Ctrl+Shift+Z and Ctrl+Y', () => {
      const { root, host } = mountFocused();
      typeText(root, 'ab');

      expect(pressKey(root, 'z', { ctrlKey: true }).defaultPrevented).toBe(
        true
      );
      expect(host.value).toBe('');
      pressKey(root, 'Z', { ctrlKey: true, shiftKey: true });
      expect(host.value).toBe('ab');
      pressKey(root, 'z', { ctrlKey: true });
      pressKey(root, 'y', { ctrlKey: true });
      expect(host.value).toBe('ab');
    });

    it('takes Cmd+Z on Apple platforms', () => {
      jest.spyOn(navigator, 'platform', 'get').mockReturnValue('MacIntel');
      const { root, host } = mountFocused();
      typeText(root, 'ab');

      // Ctrl+Z is not undo on a Mac.
      expect(pressKey(root, 'z', { ctrlKey: true }).defaultPrevented).toBe(
        false
      );
      expect(host.value).toBe('ab');
      pressKey(root, 'z', { metaKey: true });
      expect(host.value).toBe('');
      pressKey(root, 'z', { metaKey: true, shiftKey: true });
      expect(host.value).toBe('ab');
    });

    it('leaves other shortcuts to the browser', () => {
      const { root } = mountFocused();
      typeText(root, 'ab');

      expect(pressKey(root, 'z').defaultPrevented).toBe(false);
      expect(pressKey(root, 'a', { ctrlKey: true }).defaultPrevented).toBe(
        false
      );
      expect(
        pressKey(root, 'z', { ctrlKey: true, altKey: true }).defaultPrevented
      ).toBe(false);
    });

    it('ignores the shortcuts on a read-only editor', () => {
      const { root, host } = mountFocused();
      typeText(root, 'ab');
      host.setEditable(false);

      pressKey(root, 'z', { ctrlKey: true });
      expect(host.value).toBe('ab');
    });
  });

  it('clears the history when setValue loads a new document', async () => {
    const { root, host, histories } = mountFocused();
    typeText(root, 'ab');
    await host.setValue('fresh');

    host.undo();
    expect(host.value).toBe('fresh');
    expect(histories.at(-1)).toEqual({ canUndo: false, canRedo: false });
  });

  it('drops redo once a new edit is made', () => {
    const { root, host } = mountFocused();
    typeText(root, 'ab');
    host.undo();
    typeText(root, 'x');
    host.redo();

    expect(host.value).toBe('x');
  });

  it('keeps a stack per editor', () => {
    const first = mountFocused();
    typeText(first.root, 'one');
    const second = mountFocused();
    typeText(second.root, 'two');

    first.host.undo();
    expect(first.host.value).toBe('');
    expect(second.host.value).toBe('two');
    second.host.undo();
    expect(second.host.value).toBe('');
    first.host.redo();
    expect(first.host.value).toBe('one');
  });

  it('breaks the typing step when the caret moves', () => {
    const { root, host } = mountFocused();
    typeText(root, 'ab');
    caretAt(root, 0);
    document.dispatchEvent(new Event('selectionchange'));
    typeText(root, 'x');

    host.undo();
    expect(host.value).toBe('ab');
  });

  it('redoes to the end of the edit after the caret moved away', () => {
    const mounted = mountFocused();
    typeText(mounted.root, 'hello');
    caretAt(mounted.root, 0);
    document.dispatchEvent(new Event('selectionchange'));

    mounted.host.undo();
    mounted.host.redo();
    expect(mounted.host.value).toBe('hello');
    expect(mounted.selections.at(-1)).toEqual(caret(5));
  });

  it('breaks the typing step after a pause', () => {
    let time = 0;
    jest.spyOn(performance, 'now').mockImplementation(() => time);
    const { root, host } = mountFocused();
    typeText(root, 'ab');
    time += 1000;
    typeText(root, 'cd');

    host.undo();
    expect(host.value).toBe('ab');
  });

  it('reports the history state only when it flips', () => {
    const { root, host, histories } = mountFocused();
    typeText(root, 'a');
    typeText(root, 'b');
    sendInput(root, 'insertParagraph');
    host.undo();
    host.undo();
    host.redo();
    host.redo();
    typeText(root, 'c');

    expect(histories).toEqual([
      { canUndo: true, canRedo: false },
      { canUndo: true, canRedo: true },
      { canUndo: false, canRedo: true },
      { canUndo: true, canRedo: true },
      { canUndo: true, canRedo: false },
    ]);
  });
});
