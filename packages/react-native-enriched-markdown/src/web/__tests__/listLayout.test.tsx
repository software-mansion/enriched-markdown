/**
 * @jest-environment jsdom
 */
import { act } from 'react';
import { createPortal } from 'react-dom';
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
  Object.defineProperty(HTMLElement.prototype, 'offsetWidth', {
    configurable: true,
    get(this: HTMLElement) {
      return /\d{3}\./.test(this.textContent ?? '') ? 35 : 25;
    },
  });
});

afterEach(() => {
  act(() => root.unmount());
  container.remove();
  delete (HTMLElement.prototype as { offsetWidth?: number }).offsetWidth;
});

it('fits the number column to the widest number', () => {
  act(() =>
    root.render(
      <EnrichedMarkdownText markdown={'99. a\n100. b\n     - child'} />
    )
  );

  const [ninetyNine, hundred] = Array.from(
    container.querySelectorAll<HTMLElement>('ol > li')
  );
  expect(ninetyNine!.style.marginInlineStart).toBe('47px');
  expect(hundred!.style.marginInlineStart).toBe('47px');
  expect(
    container.querySelector<HTMLElement>('ol ul')!.style.marginInlineStart
  ).toBe('-13px');
});

it('brings its rules into an iframe it renders into', () => {
  const frame = document.createElement('iframe');
  container.appendChild(frame);
  const body = frame.contentDocument!.body;
  act(() =>
    root.render(createPortal(<EnrichedMarkdownText markdown="- a" />, body))
  );

  expect(
    frame.contentDocument!.getElementById('enrm-list-markers')
  ).not.toBeNull();
});
