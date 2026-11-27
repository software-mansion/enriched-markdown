/**
 * @jest-environment jsdom
 */
import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { TextEncoder } from 'util';
import { loadParser } from '../parseMarkdown';

jest.mock('react-native', () => ({
  Platform: { OS: 'web' },
  processColor: (color: unknown) => color,
}));

globalThis.TextEncoder ??= TextEncoder as typeof globalThis.TextEncoder;
const { EnrichedMarkdownText } =
  require('../EnrichedMarkdownText') as typeof import('../EnrichedMarkdownText');

(
  globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }
).IS_REACT_ACT_ENVIRONMENT = true;

let container: HTMLDivElement;
let root: Root;

beforeAll(() => loadParser());

beforeEach(() => {
  container = document.createElement('div');
  document.body.appendChild(container);
  root = createRoot(container);
});

afterEach(() => {
  act(() => root.unmount());
  container.remove();
});

function clickLink(url: string, init: MouseEventInit = {}) {
  const onLinkPress = jest.fn();
  act(() =>
    root.render(
      <EnrichedMarkdownText
        markdown={`[link](${url})`}
        onLinkPress={onLinkPress}
      />
    )
  );
  const event = new MouseEvent('click', {
    bubbles: true,
    cancelable: true,
    ...init,
  });
  act(() => {
    container.querySelector('a')!.dispatchEvent(event);
  });
  return { onLinkPress, prevented: event.defaultPrevented };
}

it('sends a plain click to onLinkPress', () => {
  const { onLinkPress, prevented } = clickLink('https://example.com');
  expect(onLinkPress).toHaveBeenCalledWith({ url: 'https://example.com' });
  expect(prevented).toBe(true);
});

it.each([
  ['https://example.com', { metaKey: true }],
  ['docs/page', { ctrlKey: true }],
  ['../page', { shiftKey: true }],
  ['tel:123', { metaKey: true }],
])('leaves a modified click on %s to the browser', (url, init) => {
  const { onLinkPress, prevented } = clickLink(url, init);
  expect(onLinkPress).not.toHaveBeenCalled();
  expect(prevented).toBe(false);
});

it('sends a modified click on a custom scheme to onLinkPress', () => {
  const { onLinkPress, prevented } = clickLink('user://42', { metaKey: true });
  expect(onLinkPress).toHaveBeenCalledWith({ url: 'user://42' });
  expect(prevented).toBe(true);
});
