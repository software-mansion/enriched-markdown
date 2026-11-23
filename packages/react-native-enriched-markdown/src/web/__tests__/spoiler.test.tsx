/**
 * @jest-environment jsdom
 */
import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { TextEncoder } from 'util';
import type { EnrichedMarkdownTextProps } from '../../types/MarkdownTextProps.web';
import { loadParser } from '../parseMarkdown';

// Off web, normalizeColor turns a custom color into a native color number.
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

function render(props: EnrichedMarkdownTextProps) {
  act(() => root.render(<EnrichedMarkdownText {...props} />));
}

function spoilers(): HTMLElement[] {
  return Array.from(container.querySelectorAll<HTMLElement>('.enrm-spoiler'));
}

function onlySpoiler(): HTMLElement {
  const [spoiler, ...rest] = spoilers();
  if (!spoiler || rest.length > 0) {
    throw new Error(`Expected one spoiler, found ${spoilers().length}`);
  }
  return spoiler;
}

function isConcealed(spoiler: HTMLElement): boolean {
  return (spoiler.firstElementChild as HTMLElement).style.opacity === '0';
}

function press(element: Element): MouseEvent {
  const event = new MouseEvent('click', { bubbles: true, cancelable: true });
  act(() => {
    element.dispatchEvent(event);
  });
  return event;
}

it('conceals the text under a button a screen reader still reads through', () => {
  render({
    markdown: 'a ||secret|| b',
    markdownStyle: {
      spoiler: { color: 'rgb(1, 2, 3)', solid: { borderRadius: 9 } },
    },
  });

  expect(container.textContent).toBe('a secret b');
  const spoiler = onlySpoiler();
  expect(isConcealed(spoiler)).toBe(true);
  expect(spoiler.style.backgroundColor).toBe('rgb(1, 2, 3)');
  expect(spoiler.style.borderRadius).toBe('9px');
  expect(spoiler.getAttribute('role')).toBe('button');
  expect(spoiler.hasAttribute('aria-label')).toBe(false);
  expect(container.querySelector('[aria-hidden]')).toBeNull();
});

it('reveals one spoiler per click, and for good', () => {
  render({ markdown: 'The password is ||swordfish|| and the code is ||42||.' });

  const [first, second] = spoilers();
  press(first!);
  press(first!);

  expect(isConcealed(first!)).toBe(false);
  expect(first!.style.backgroundColor).toBe('transparent');
  expect(isConcealed(second!)).toBe(true);
});

it.each(['Enter', ' '])(
  'reveals with %p and keeps the keyboard focus',
  (key) => {
    render({ markdown: '||secret||' });
    onlySpoiler().focus();

    const event = new KeyboardEvent('keydown', {
      key,
      bubbles: true,
      cancelable: true,
    });
    act(() => {
      onlySpoiler().dispatchEvent(event);
    });

    expect(event.defaultPrevented).toBe(true);
    expect(isConcealed(onlySpoiler())).toBe(false);
    expect(onlySpoiler().getAttribute('tabindex')).toBe('-1');
    expect(onlySpoiler().hasAttribute('role')).toBe(false);
    expect(document.activeElement).toBe(onlySpoiler());
  }
);

it('stays concealed when the click ends a text selection', () => {
  render({ markdown: '||a long secret to select||' });

  window.getSelection()!.selectAllChildren(onlySpoiler());
  press(onlySpoiler());
  expect(isConcealed(onlySpoiler())).toBe(true);

  window.getSelection()!.removeAllRanges();
  press(onlySpoiler());
  expect(isConcealed(onlySpoiler())).toBe(false);
});

it('animates only the reveal, so concealing again shows nothing', () => {
  render({ markdown: 'a ||secret|| b' });
  expect(onlySpoiler().hasAttribute('data-revealed')).toBe(false);
  press(onlySpoiler());
  expect(onlySpoiler().hasAttribute('data-revealed')).toBe(true);

  const css = document.getElementById('enrm-spoiler-reveal')?.textContent ?? '';
  const animated = css
    .split('}')
    .filter((rule) => /transition:\s*(?!none)/.test(rule));
  expect(animated.length).toBeGreaterThan(0);
  for (const rule of animated) {
    expect(rule.split('{').at(-2)).toContain('[data-revealed]');
  }
});

it('keeps a link inside a concealed spoiler from being a link until revealed', () => {
  const onLinkPress = jest.fn();
  render({ markdown: '||see [the docs](https://example.com)||', onLinkPress });

  expect(container.querySelector('a')).toBeNull();
  press(onlySpoiler().querySelector('span span')!);
  expect(onLinkPress).not.toHaveBeenCalled();

  press(container.querySelector('a')!);
  expect(onLinkPress).toHaveBeenCalledWith({ url: 'https://example.com' });
});

it('keeps an image inside a concealed spoiler from being pressable until revealed', () => {
  render({
    markdown: '||photo ![tree](https://example.com/tree.png) here||',
    onImagePress: jest.fn(),
  });

  expect(container.querySelector('img')?.hasAttribute('role')).toBe(false);
  press(onlySpoiler());
  expect(container.querySelector('img')?.getAttribute('role')).toBe('button');
});

it('reveals a spoiler inside a link instead of following the link', () => {
  const onLinkPress = jest.fn();
  render({
    markdown: '[see ||the ending||](https://example.com)',
    onLinkPress,
  });

  expect(press(onlySpoiler()).defaultPrevented).toBe(true);
  expect(onLinkPress).not.toHaveBeenCalled();
  expect(isConcealed(onlySpoiler())).toBe(false);
});

it('conceals again only when the spoiler text itself changes', () => {
  render({ markdown: 'a ||secret|| b' });
  press(onlySpoiler());

  render({
    markdown: 'a ||secret|| b',
    markdownStyle: { spoiler: { color: 'rgb(1, 2, 3)' } },
  });
  render({ markdown: 'a ||secret|| b, and more streamed text' });
  expect(isConcealed(onlySpoiler())).toBe(false);

  render({ markdown: 'a ||another|| b' });
  expect(isConcealed(onlySpoiler())).toBe(true);
  render({ markdown: 'a ||secret|| b' });
  expect(isConcealed(onlySpoiler())).toBe(true);
});
