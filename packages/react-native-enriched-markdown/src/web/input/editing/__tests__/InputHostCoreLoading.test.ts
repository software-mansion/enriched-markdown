/**
 * @jest-environment jsdom
 */
import type { MountedHost } from './inputHostKit';

// The markdown comes from the C++ core in the WASM module, which loads
// asynchronously, while `getMarkdown` and the copy handler are synchronous.
// Every test starts from a registry where the module has not loaded.

interface Fresh {
  mount: () => MountedHost;
  selectRangeFocused: (root: HTMLElement, start: number, end: number) => void;
  typeText: (root: HTMLElement, data: string) => void;
  loadParser: () => Promise<void>;
}

function fresh(options?: { failingLoad?: boolean }): Fresh {
  jest.resetModules();
  if (options?.failingLoad) {
    jest.doMock('../../../wasm/md4c', () => ({
      __esModule: true,
      default: () => Promise.reject(new Error('WASM unavailable')),
    }));
  } else {
    jest.dontMock('../../../wasm/md4c');
  }
  const kit = require('./inputHostKit');
  const { loadParser } = require('../../../parseMarkdown');
  return {
    mount: kit.mount,
    selectRangeFocused: kit.selectRangeFocused,
    typeText: kit.typeText,
    loadParser,
  };
}

function clipboardEvent() {
  const event = new Event('copy', { bubbles: true, cancelable: true });
  const written = new Map<string, string>();
  Object.defineProperty(event, 'clipboardData', {
    value: {
      getData: () => '',
      setData: (mime: string, value: string) => written.set(mime, value),
    },
  });
  return { event, written };
}

let warn: jest.SpyInstance;

beforeEach(() => {
  warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
});

afterEach(() => {
  warn.mockRestore();
  jest.dontMock('../../../wasm/md4c');
  document.body.replaceChildren();
});

describe('before the markdown core has loaded', () => {
  it('holds onChangeMarkdown, then emits once with the current value', async () => {
    const { mount, loadParser, typeText } = fresh();
    const { host, root, markdowns } = mount();

    typeText(root, 'a*b');
    typeText(root, '*c');
    expect(host.value).toBe('a*b*c');
    expect(markdowns).toEqual([]);

    await loadParser();
    await Promise.resolve();

    expect(markdowns).toEqual(['a\\*b\\*c']);
    typeText(root, '!');
    expect(markdowns).toEqual(['a\\*b\\*c', 'a\\*b\\*c!']);
  });

  it('emits nothing at load when no edit was held', async () => {
    const { mount, loadParser } = fresh();
    const { markdowns } = mount();

    await loadParser();
    await Promise.resolve();

    expect(markdowns).toEqual([]);
  });

  it('returns the plain text from getMarkdown and warns once', async () => {
    const { mount, loadParser, typeText } = fresh();
    const { host, root } = mount();
    typeText(root, 'a*b');

    expect(host.getMarkdown()).toBe('a*b');
    expect(host.getMarkdown()).toBe('a*b');
    expect(warn).toHaveBeenCalledTimes(1);

    await loadParser();
    expect(host.getMarkdown()).toBe('a\\*b');
    expect(warn).toHaveBeenCalledTimes(1);
  });

  it('copies the selection as plain text in the markdown flavor too', async () => {
    const { mount, selectRangeFocused, typeText } = fresh();
    const { root } = mount();
    typeText(root, 'a*b*c');
    selectRangeFocused(root, 1, 4);
    const { event, written } = clipboardEvent();

    root.dispatchEvent(event);

    expect(event.defaultPrevented).toBe(true);
    expect(written.get('text/plain')).toBe('*b*');
    expect(written.get('text/markdown')).toBe('*b*');
    expect(warn).toHaveBeenCalledTimes(1);
  });

  it('emits nothing for a host destroyed while it loads', async () => {
    const { mount, loadParser, typeText } = fresh();
    const { host, root, markdowns } = mount();
    typeText(root, 'abc');
    host.destroy();

    await loadParser();
    await Promise.resolve();

    expect(markdowns).toEqual([]);
  });
});

describe('when the markdown core fails to load', () => {
  it('emits the plain text and keeps returning it, warning once', async () => {
    const { mount, typeText } = fresh({ failingLoad: true });
    const { host, root, markdowns } = mount();

    typeText(root, 'a*b');
    expect(markdowns).toEqual([]);

    // Let the failed load settle.
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(markdowns).toEqual(['a*b']);
    expect(host.getMarkdown()).toBe('a*b');
    expect(warn).toHaveBeenCalledTimes(1);
  });

  it('copies the selection as plain text', async () => {
    const { mount, selectRangeFocused, typeText } = fresh({
      failingLoad: true,
    });
    const { root } = mount();
    typeText(root, 'a*b*c');
    selectRangeFocused(root, 1, 4);
    const { event, written } = clipboardEvent();

    root.dispatchEvent(event);

    expect(written.get('text/markdown')).toBe('*b*');
  });

  it('imports a value as plain text', async () => {
    const { mount } = fresh({ failingLoad: true });
    const { host } = mount();

    await host.setValue('**bold**');

    expect(host.value).toBe('**bold**');
  });
});
