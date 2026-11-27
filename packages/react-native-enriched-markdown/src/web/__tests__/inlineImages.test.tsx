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

function imageIsInline(markdown: string): boolean {
  act(() => root.render(<EnrichedMarkdownText markdown={markdown} />));
  return container.querySelector('img')!.style.display !== 'block';
}

// An image is inline when its paragraph, heading or table cell holds anything
// besides images, however deeply the image is wrapped (#1081).
it.each([
  'Play [![](https://example.com/t.png) Catan](https://example.com) tonight',
  'See [![badge](https://example.com/b.svg)](https://example.com) for status',
  'text **![](https://example.com/x.png)**',
  '# Title ![](https://example.com/x.png)',
  '| a |\n| --- |\n| text ![](https://example.com/x.png) |',
])('draws an image next to text inline: %s', (markdown) => {
  expect(imageIsInline(markdown)).toBe(true);
});

it.each([
  '![](https://example.com/x.png)',
  '[![badge](https://example.com/b.svg)](https://example.com)',
])('keeps an image alone in its paragraph a block: %s', (markdown) => {
  expect(imageIsInline(markdown)).toBe(false);
});

// An image-only spoiler wraps its image in a cover box, which flows inline next to text.
it('draws an image-only spoiler next to text inline', () => {
  imageIsInline('text ||![](https://example.com/x.png)||');
  expect(container.querySelector('img')!.parentElement!.style.display).toBe(
    'inline-block'
  );
});
