/**
 * @jest-environment jsdom
 */
// The React shell around `InputHost`: what it hands the host at mount, what it
// forwards to the DOM node the host owns, and when the imperative handle is
// usable. Most of what lives here is lifecycle ordering, which only a real
// renderer reproduces, so this suite drives `react-dom` rather than the host
// directly.
import { act, useLayoutEffect, useRef } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
  type EnrichedMarkdownTextInputProps,
} from '../src/EnrichedMarkdownTextInput.web';
import { parseToPlainTextAndRanges } from '../src/web/input/formatting/InputParser';
import { serialize } from '../src/web/input/formatting/MarkdownSerializer';

jest.mock('../src/web/input/formatting/InputParser', () => ({
  parseToPlainTextAndRanges: jest.fn(),
}));

jest.mock('../src/web/input/formatting/MarkdownSerializer', () => {
  const actual = jest.requireActual(
    '../src/web/input/formatting/MarkdownSerializer'
  );
  return { serialize: jest.fn(actual.serialize) };
});

const parse = parseToPlainTextAndRanges as jest.MockedFunction<
  typeof parseToPlainTextAndRanges
>;
const serializeCalls = serialize as jest.MockedFunction<typeof serialize>;

(
  globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }
).IS_REACT_ACT_ENVIRONMENT = true;

// Stands in for the wasm parser: enough of one to carry a bold run through an
// import and back out of the real serializer.
function fakeParse(markdown: string) {
  const bold = /^\*\*(.*)\*\*$/.exec(markdown);
  if (bold !== null) {
    const plainText = bold[1]!;
    return {
      plainText,
      formattingRanges: [
        { type: 'strong' as const, start: 0, end: plainText.length },
      ],
      blockRanges: [],
    };
  }
  return { plainText: markdown, formattingRanges: [], blockRanges: [] };
}

interface Mounted {
  editor: HTMLElement;
  ref: { current: EnrichedMarkdownTextInputInstance | null };
  render: (props: EnrichedMarkdownTextInputProps) => void;
  unmount: () => void;
}

const roots: Root[] = [];

function mount(props: EnrichedMarkdownTextInputProps = {}): Mounted {
  const container = document.createElement('div');
  document.body.appendChild(container);
  const root = createRoot(container);
  roots.push(root);
  const ref: { current: EnrichedMarkdownTextInputInstance | null } = {
    current: null,
  };
  const render = (next: EnrichedMarkdownTextInputProps) => {
    act(() => {
      root.render(<EnrichedMarkdownTextInput ref={ref} {...next} />);
    });
  };
  render(props);
  return {
    editor: container.firstElementChild as HTMLElement,
    ref,
    render,
    unmount: () => act(() => root.unmount()),
  };
}

beforeEach(() => {
  parse.mockImplementation(async (markdown: string) => fakeParse(markdown));
  // jsdom has no `Range.getBoundingClientRect`, and the caret rect commands
  // reach for it.
  Range.prototype.getBoundingClientRect = () => ({ ...ZERO_RECT }) as DOMRect;
});

const ZERO_RECT = {
  left: 0,
  top: 0,
  width: 0,
  height: 0,
  x: 0,
  y: 0,
  right: 0,
  bottom: 0,
};

afterEach(() => {
  for (const root of roots.splice(0)) {
    act(() => root.unmount());
  }
  delete (Range.prototype as Partial<Range>).getBoundingClientRect;
  jest.restoreAllMocks();
  document.body.replaceChildren();
});

describe('defaultValue', () => {
  // The app supplied this markdown, so reporting it back would have
  // `onChangeMarkdown` hand the app the serializer's re-normalization of its
  // own source string. Neither native emits for a `defaultValue`, which is
  // what `InputHost.importValue` exists for.
  it('loads without reporting anything back', async () => {
    const callbacks = {
      onChangeText: jest.fn(),
      onChangeSelection: jest.fn(),
      onChangeState: jest.fn(),
      onChangeMarkdown: jest.fn(),
    };
    const { editor } = mount({ defaultValue: '**bold**', ...callbacks });

    await act(async () => undefined);

    expect(editor.textContent).toBe('bold');
    expect(callbacks.onChangeText).not.toHaveBeenCalled();
    expect(callbacks.onChangeSelection).not.toHaveBeenCalled();
    expect(callbacks.onChangeState).not.toHaveBeenCalled();
    expect(callbacks.onChangeMarkdown).not.toHaveBeenCalled();
  });

  // The command path is the other half of the same split: it reports, the way
  // iOS's `setValue:` re-emits once its import returns.
  it('is the one import that stays quiet - setValue reports', async () => {
    const onChangeText = jest.fn();
    const onChangeMarkdown = jest.fn();
    const { ref } = mount({ onChangeText, onChangeMarkdown });

    await act(async () => {
      ref.current!.setValue('**bold**');
    });

    expect(onChangeText).toHaveBeenCalledWith('bold');
    expect(onChangeMarkdown).toHaveBeenCalledWith('**bold**');
  });

  it('is read once, so a later change does not reimport', async () => {
    const { editor, render } = mount({ defaultValue: 'first' });
    await act(async () => undefined);
    expect(editor.textContent).toBe('first');

    render({ defaultValue: 'second' });
    await act(async () => undefined);

    expect(editor.textContent).toBe('first');
  });
});

describe('the editor node', () => {
  // Every rule in `INPUT_CSS` is scoped under this class, and the host adding
  // it imperatively is not enough: React remembers only the caller's value
  // and rewrites the attribute wholesale the first time `className` changes.
  it('keeps its own class alongside a forwarded className', () => {
    const { editor, render } = mount({ className: 'ring' });
    expect([...editor.classList]).toEqual(['enrm-input', 'ring']);

    render({ className: 'other' });

    expect([...editor.classList]).toEqual(['enrm-input', 'other']);
  });

  it('carries its own class with no className supplied', () => {
    const { editor } = mount();

    expect([...editor.classList]).toEqual(['enrm-input']);
  });

  it('forwards the dom props it does not own', () => {
    const { editor } = mount({ 'id': 'editor', 'aria-label': 'Notes' });

    expect(editor.id).toBe('editor');
    expect(editor.getAttribute('aria-label')).toBe('Notes');
  });

  it('passes spellCheck on to the host', () => {
    const { editor } = mount({ spellCheck: false });

    expect(editor.getAttribute('spellcheck')).toBe('false');
  });

  it('leaves spellcheck to the browser when the prop is absent', () => {
    const { editor } = mount();

    expect(editor.hasAttribute('spellcheck')).toBe(false);
  });

  it('puts the placeholder and its color on the node', () => {
    const { editor } = mount({
      placeholder: 'Write something',
      placeholderTextColor: 'rebeccapurple',
    });

    expect(editor.getAttribute('data-placeholder')).toBe('Write something');
    expect(editor.style.getPropertyValue('--enrm-placeholder-color')).toBe(
      'rebeccapurple'
    );
  });

  // The props the host owns outright. React re-applies a prop on every render
  // and gives no diagnostic when it undoes something set imperatively, so
  // these are kept off the public surface rather than merged.
  it('does not accept the props the host owns', () => {
    const ownedByHost: EnrichedMarkdownTextInputProps[] = [
      {
        // @ts-expect-error - the renderer rewrites this subtree by index
        children: 'fallback',
      },
      {
        // @ts-expect-error - same subtree, written straight past the renderer
        dangerouslySetInnerHTML: { __html: '<b>x</b>' },
      },
      {
        // @ts-expect-error - React would re-apply this over `editable`
        contentEditable: false,
      },
    ];

    expect(ownedByHost).toHaveLength(3);
  });
});

describe('editable', () => {
  it('reaches both the host and the accessibility tree', () => {
    const { editor, render } = mount({ editable: false });
    expect(editor.getAttribute('contenteditable')).toBe('false');
    expect(editor.getAttribute('aria-disabled')).toBe('true');

    render({ editable: true });

    expect(editor.getAttribute('contenteditable')).toBe('true');
    expect(editor.getAttribute('aria-disabled')).toBe('false');
  });

  it('is applied before an autoFocus can land on the node', () => {
    const { editor } = mount({ editable: false, autoFocus: true });

    expect(editor.getAttribute('contenteditable')).toBe('false');
  });
});

describe('autoFocus', () => {
  // `focus()` dispatches its event synchronously, so the listener has to be
  // registered before the focus, not in a later effect.
  it('delivers onFocus for the focus it causes', () => {
    const onFocus = jest.fn();
    const { editor } = mount({ autoFocus: true, onFocus });

    expect(document.activeElement).toBe(editor);
    expect(onFocus).toHaveBeenCalledTimes(1);
  });

  it('leaves the node unfocused when not asked for', () => {
    const onFocus = jest.fn();
    const { editor } = mount({ onFocus });

    expect(document.activeElement).not.toBe(editor);
    expect(onFocus).not.toHaveBeenCalled();
  });

  it('reports a blur too', () => {
    const onBlur = jest.fn();
    const { editor } = mount({ autoFocus: true, onBlur });

    editor.blur();

    expect(onBlur).toHaveBeenCalledTimes(1);
  });
});

describe('the imperative handle', () => {
  // The handle is installed in the layout phase, so the host has to exist by
  // then: a parent driving the input from its own layout effect or from a ref
  // callback runs after this component's, and a command issued there would
  // otherwise be dropped with no diagnostic at all.
  it('works from a parent layout effect, before the first paint', () => {
    const onChangeText = jest.fn();

    function Harness() {
      const ref = useRef<EnrichedMarkdownTextInputInstance>(null);
      useLayoutEffect(() => {
        ref.current!.insertText('typed before paint');
      }, []);
      return (
        <EnrichedMarkdownTextInput ref={ref} onChangeText={onChangeText} />
      );
    }

    const container = document.createElement('div');
    document.body.appendChild(container);
    const root = createRoot(container);
    roots.push(root);
    act(() => root.render(<Harness />));

    expect(onChangeText).toHaveBeenCalledWith('typed before paint');
  });

  it('holds a command behind an import and runs it on the new document', async () => {
    const { ref } = mount();

    await act(async () => {
      ref.current!.setValue('**bold**');
      ref.current!.insertText('!');
    });

    await expect(ref.current!.getMarkdown()).resolves.toBe('**bold**!');
  });

  it('answers getMarkdown after the import it was issued behind', async () => {
    const { ref } = mount();

    const markdown = act(async () => {
      ref.current!.setValue('**bold**');
      return ref.current!.getMarkdown();
    });

    await expect(markdown).resolves.toBe('**bold**');
  });

  it('answers a caret rect relative to the editor', async () => {
    const { ref } = mount();

    await expect(ref.current!.getCaretRect()).resolves.toEqual({
      x: 0,
      y: 0,
      width: 0,
      height: 0,
    });
  });

  it('warns once for a command web does not implement yet', () => {
    const warned = jest.spyOn(console, 'warn').mockImplementation(() => {});
    const { ref } = mount();

    ref.current!.setLink('https://x.test');
    ref.current!.setLink('https://y.test');

    expect(warned).toHaveBeenCalledTimes(1);
    expect(warned.mock.calls[0]![0]).toContain('setLink');
  });

  it('warns for each command web does not implement yet', () => {
    const warned = jest.spyOn(console, 'warn').mockImplementation(() => {});
    const { ref } = mount();
    const handle = ref.current!;

    handle.setLink('https://x.test');
    handle.insertLink('text', 'https://x.test');
    handle.removeLink();
    handle.insertMention('name', 'https://x.test');
    handle.startMention('@');
    handle.copyToClipboard();

    expect(warned.mock.calls.map(([message]) => message)).toEqual([
      expect.stringContaining('setLink'),
      expect.stringContaining('insertLink'),
      expect.stringContaining('removeLink'),
      expect.stringContaining('insertMention'),
      expect.stringContaining('startMention'),
      expect.stringContaining('copyToClipboard'),
    ]);
  });

  // Every inline toggle and list command reaches the host. Asserted through
  // the markdown rather than one mock per command, so the wiring is checked
  // against what the document actually becomes.
  it('forwards every formatting command to the host', async () => {
    const { ref } = mount();
    const handle = ref.current!;

    act(() => {
      handle.insertText('text');
      handle.setSelection(0, 4);
      handle.toggleBold();
      handle.toggleItalic();
      handle.toggleUnderline();
      handle.toggleStrikethrough();
      handle.toggleSpoiler();
    });

    await expect(handle.getMarkdown()).resolves.toBe('***_~~||text||~~_***');
  });

  it('forwards the list commands to the host', async () => {
    const { ref } = mount();
    const handle = ref.current!;

    act(() => {
      handle.insertText('item');
      handle.toggleUnorderedList();
      handle.indentList();
    });
    await expect(handle.getMarkdown()).resolves.toContain('item');

    act(() => {
      handle.outdentList();
      handle.toggleOrderedList();
    });

    await expect(handle.getMarkdown()).resolves.toBe('1. item');
  });

  it('forwards focus and blur to the host', () => {
    const { editor, ref } = mount();

    act(() => ref.current!.focus());
    expect(document.activeElement).toBe(editor);

    act(() => ref.current!.blur());
    expect(document.activeElement).not.toBe(editor);
  });

  it('measures the editor node', () => {
    jest.useFakeTimers();
    const { editor, ref } = mount();
    editor.getBoundingClientRect = () =>
      ({ left: 12, top: 34, width: 56, height: 78 }) as DOMRect;
    const onMeasure = jest.fn();
    const onLayout = jest.fn();

    ref.current!.measureInWindow(onMeasure);
    ref.current!.measureLayout(editor.parentElement!, onLayout);
    jest.runAllTimers();
    jest.useRealTimers();

    expect(onMeasure).toHaveBeenCalledWith(12, 34, 56, 78);
    expect(onLayout).toHaveBeenCalledWith(0, 0, 0, 0);
  });
});

describe('onChangeState', () => {
  // The web model uses 0 for "no heading", and `StyleState.heading.level` is
  // typed 1..6 - so a consumer indexing a table by it, or switching
  // exhaustively, has no branch for 0. Native normalizes the same field.
  it('normalizes the no-heading sentinel the way native does', () => {
    const onChangeState = jest.fn();
    const { ref } = mount({ onChangeState });

    act(() => {
      ref.current!.insertText('plain');
    });

    expect(onChangeState).toHaveBeenCalledWith(
      expect.objectContaining({ heading: { isActive: false, level: 1 } })
    );
  });

  it('reports a real heading level unchanged', () => {
    const onChangeState = jest.fn();
    const { ref } = mount({ onChangeState });

    act(() => {
      ref.current!.insertText('head');
      ref.current!.toggleHeading(3);
    });

    expect(onChangeState).toHaveBeenLastCalledWith(
      expect.objectContaining({ heading: { isActive: true, level: 3 } })
    );
  });
});

describe('onChangeMarkdown', () => {
  // The host short-circuits when nothing is listening, but it cannot tell
  // from the callback alone: the wrapper's forwarding closure is there either
  // way. Without the switch, every consumer pays a full-document serialize per
  // keystroke to feed a callback nobody passed.
  it('does not serialize the document while nobody is listening', () => {
    const { ref } = mount();
    serializeCalls.mockClear();

    act(() => {
      ref.current!.insertText('hi');
    });

    expect(serializeCalls).not.toHaveBeenCalled();
  });

  it('serializes once a listener arrives, and stops when it leaves', () => {
    const onChangeMarkdown = jest.fn();
    const { ref, render } = mount();

    render({ onChangeMarkdown });
    act(() => {
      ref.current!.insertText('hi');
    });
    expect(onChangeMarkdown).toHaveBeenCalledWith('hi');

    render({});
    serializeCalls.mockClear();
    act(() => {
      ref.current!.insertText('!');
    });

    expect(serializeCalls).not.toHaveBeenCalled();
  });

  it('calls the latest callback the props carried', () => {
    const first = jest.fn();
    const second = jest.fn();
    const { ref, render } = mount({ onChangeMarkdown: first });

    render({ onChangeMarkdown: second });
    act(() => {
      ref.current!.insertText('hi');
    });

    expect(first).not.toHaveBeenCalled();
    expect(second).toHaveBeenCalledWith('hi');
  });
});

describe('unmount', () => {
  it('stops routing the events it registered', () => {
    const onFocus = jest.fn();
    const onBlur = jest.fn();
    const { editor, unmount } = mount({ onFocus, onBlur });

    unmount();
    editor.dispatchEvent(new Event('focus'));
    editor.dispatchEvent(new Event('blur'));

    expect(onFocus).not.toHaveBeenCalled();
    expect(onBlur).not.toHaveBeenCalled();
  });

  it('leaves no editable node behind', () => {
    const { editor, unmount } = mount();

    unmount();

    expect(editor.hasAttribute('contenteditable')).toBe(false);
    expect(editor.hasAttribute('data-empty')).toBe(false);
  });
});
