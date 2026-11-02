/**
 * @jest-environment jsdom
 */
import { InputHost } from '../InputHost';
import { parseToPlainTextAndRanges } from '../../formatting/InputParser';
import type { ParseResult } from '../../formatting/InputParser';

jest.mock('../../formatting/InputParser', () => ({
  parseToPlainTextAndRanges: jest.fn(),
}));

const parse = parseToPlainTextAndRanges as jest.MockedFunction<
  typeof parseToPlainTextAndRanges
>;

// The parse is the asynchronous step every import has to survive: a keystroke,
// a second import or an unmount can all land while it is in flight.
function deferParse(plainText: string) {
  let release!: () => void;
  const parsed = new Promise<void>((resolve) => {
    release = resolve;
  });
  parse.mockImplementationOnce(async () => {
    await parsed;
    return {
      plainText,
      formattingRanges: [],
      blockRanges: [],
    } satisfies ParseResult;
  });
  return async () => {
    release();
    await parsed;
    // One more turn, so the continuation after the host's own `await` runs.
    await Promise.resolve();
  };
}

function mount() {
  const root = document.createElement('div');
  document.body.appendChild(root);
  const texts: string[] = [];
  const markdowns: string[] = [];
  const host = new InputHost(root, {
    onChangeText: (text) => texts.push(text),
    onChangeMarkdown: (markdown) => markdowns.push(markdown),
  });
  return { root, host, texts, markdowns };
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

describe('InputHost imports', () => {
  afterEach(() => {
    document.body.replaceChildren();
    parse.mockReset();
  });

  // The prop path: the app already holds this value, so reporting it back is
  // an extra render and a feedback loop for anyone echoing it into state.
  // Neither native does it.
  it('importValue loads the markdown without reporting it', async () => {
    const { host, texts } = mount();
    const finish = deferParse('loaded');
    const importing = host.importValue('# loaded');
    await finish();
    await importing;

    expect(host.value).toBe('loaded');
    expect(texts).toEqual([]);
  });

  // The imperative command path, which iOS re-emits on deliberately.
  it('setValue loads the markdown and reports it', async () => {
    const { host, texts } = mount();
    const finish = deferParse('loaded');
    const setting = host.setValue('# loaded');
    await finish();
    await setting;

    expect(host.value).toBe('loaded');
    expect(texts).toEqual(['loaded']);
  });

  it('setValue does not re-emit markdown the listener already has', async () => {
    const { host, markdowns } = mount();
    let finish = deferParse('loaded');
    let setting = host.setValue('loaded');
    await finish();
    await setting;
    expect(markdowns).toEqual(['loaded']);

    finish = deferParse('loaded');
    setting = host.setValue('loaded');
    await finish();
    await setting;

    expect(markdowns).toEqual(['loaded']);
  });

  it('renders the imported value and parks the caret at its end', async () => {
    const { root, host } = mount();
    const finish = deferParse('one\ntwo');
    const importing = host.importValue('one\ntwo');
    await finish();
    await importing;

    expect(root.textContent).toBe('onetwo');
    expect(root.children).toHaveLength(2);
    expect(host.value).toBe('one\ntwo');
  });

  // A new value replaces every line, which the host tells the projector up
  // front; the fallback for a change it was not told about stays quiet.
  it('projects an imported value without the missed-hint fallback', async () => {
    const error = jest.spyOn(console, 'error').mockImplementation(() => {});
    try {
      const { root, host } = mount();
      const finish = deferParse('one\ntwo');
      const importing = host.importValue('one\ntwo');
      await finish();
      await importing;

      expect(root.children).toHaveLength(2);
      expect(error).not.toHaveBeenCalled();
    } finally {
      error.mockRestore();
    }
  });

  // The window the parse opens is the one that needs covering: an edit
  // accepted here would be silently overwritten when the value lands.
  it('holds the editor inert while a parse is in flight', async () => {
    const { root, host } = mount();
    const finish = deferParse('loaded');
    const importing = host.importValue('# loaded');

    typeText(root, 'typed');
    expect(host.value).toBe('');

    await finish();
    await importing;
    expect(host.value).toBe('loaded');
  });

  it('a later import supersedes one still parsing', async () => {
    const { host } = mount();
    const finishFirst = deferParse('first');
    const finishSecond = deferParse('second');

    const first = host.importValue('first');
    const second = host.importValue('second');

    // The second import resolves first, so the stale one must not land on top
    // of it when it finally does.
    await finishSecond();
    await second;
    expect(host.value).toBe('second');

    await finishFirst();
    await first;
    expect(host.value).toBe('second');
  });

  it('an unmount mid-parse does not touch the detached node', async () => {
    const { root, host } = mount();
    const finish = deferParse('loaded');
    const importing = host.importValue('# loaded');

    host.destroy();
    root.remove();

    await finish();
    await expect(importing).resolves.toBeUndefined();
    expect(root.childNodes).toHaveLength(0);
  });

  // Rewriting every node under a running IME hands its leftovers to a
  // read-back that diffs them against the new model.
  it('an import that lands mid-composition waits for it to end', async () => {
    const { root, host } = mount();
    root.focus();
    typeText(root, 'ab');
    const finish = deferParse('loaded');
    const importing = host.setValue('loaded');
    root.dispatchEvent(new Event('compositionstart', { bubbles: true }));
    await finish();

    expect(root.textContent).toBe('ab');
    root.dispatchEvent(new Event('compositionend', { bubbles: true }));
    await importing;
    expect(host.value).toBe('loaded');
    expect(root.textContent).toBe('loaded');
  });

  // The wrapper's import queue waits on this promise; a dropped one stalls
  // every command and `getMarkdown` behind it.
  it('an import waiting on a composition settles when the host is destroyed', async () => {
    const { root, host } = mount();
    root.focus();
    const finish = deferParse('loaded');
    const importing = host.setValue('loaded');
    root.dispatchEvent(new Event('compositionstart', { bubbles: true }));
    await finish();
    host.destroy();

    await expect(importing).resolves.toBeUndefined();
    expect(host.value).toBe('');
  });
});
