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

function dispatch<E extends Event>(element: Element, event: E): E {
  act(() => {
    element.dispatchEvent(event);
  });
  return event;
}

const init = { bubbles: true, cancelable: true };
const press = (element: Element) =>
  dispatch(element, new MouseEvent('click', init));
const rightClick = (element: Element) =>
  dispatch(element, new MouseEvent('contextmenu', init));
const keyDown = (element: Element, key: string) =>
  dispatch(element, new KeyboardEvent('keydown', { ...init, key }));

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

    expect(keyDown(onlySpoiler(), key).defaultPrevented).toBe(true);
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

it('keeps a link inside a concealed spoiler from being a link until revealed', () => {
  const onLinkPress = jest.fn();
  render({ markdown: '||see [the docs](https://example.com)||', onLinkPress });

  expect(container.querySelector('a')).toBeNull();
  press(onlySpoiler().querySelector('span span')!);
  expect(onLinkPress).not.toHaveBeenCalled();

  press(container.querySelector('a')!);
  expect(onLinkPress).toHaveBeenCalledWith({ url: 'https://example.com' });
});

it('keeps a spoiler inside a concealed one inert until the outer one is revealed', () => {
  const onLinkPress = jest.fn();
  render({
    markdown: '||outer [||inner||](https://example.com) tail||',
    onLinkPress,
  });

  const [outer, inner] = spoilers();
  expect(outer!.getAttribute('role')).toBe('button');
  expect(inner!.hasAttribute('role')).toBe(false);
  expect(inner!.hasAttribute('tabindex')).toBe(false);

  press(inner!);
  expect(isConcealed(outer!)).toBe(false);

  const [, innerAfter] = spoilers();
  expect(isConcealed(innerAfter!)).toBe(true);
  expect(innerAfter!.getAttribute('tabindex')).toBe('0');
  press(innerAfter!);
  expect(isConcealed(innerAfter!)).toBe(false);
  expect(onLinkPress).not.toHaveBeenCalled();
});

it('handles a spoiler inside a partly visible link', () => {
  const onLinkPress = jest.fn();
  const onLinkLongPress = jest.fn();
  render({
    markdown: '[see ||the ending||](https://example.com)',
    onLinkPress,
    onLinkLongPress,
  });

  // Enter on the link follows it, since part of its label is visible.
  expect(keyDown(container.querySelector('a')!, 'Enter').defaultPrevented).toBe(
    false
  );
  // A right-click on the concealed part is no long-press on the link.
  rightClick(onlySpoiler());
  expect(onLinkLongPress).not.toHaveBeenCalled();
  // A click reveals it instead of following the link.
  expect(press(onlySpoiler()).defaultPrevented).toBe(true);
  expect(isConcealed(onlySpoiler())).toBe(false);
  expect(onLinkPress).not.toHaveBeenCalled();

  rightClick(onlySpoiler());
  expect(onLinkLongPress).toHaveBeenCalledWith({ url: 'https://example.com' });
});

it.each([
  '[||secret||](https://example.com)',
  '[**||secret||**](https://example.com)',
  '[||first||\n||second||](https://example.com)',
])(
  'reveals the hidden label of %p on Enter, even with text selected elsewhere',
  (link) => {
    const onLinkPress = jest.fn();
    render({ markdown: `other text\n\n${link}`, onLinkPress });
    window.getSelection()!.selectAllChildren(container.querySelector('p')!);
    const anchor = container.querySelector('a')!;

    expect(keyDown(anchor, 'Enter').defaultPrevented).toBe(true);
    expect(spoilers().map(isConcealed)).not.toContain(true);
    expect(onLinkPress).not.toHaveBeenCalled();
    // Revealed, the link follows as usual.
    expect(keyDown(anchor, 'Enter').defaultPrevented).toBe(false);
    window.getSelection()!.removeAllRanges();
  }
);

it('follows a link on Enter once part of its hidden label is revealed', () => {
  render({ markdown: '[||first||\n||second||](https://example.com)' });
  const [first, second] = spoilers();
  press(first!);

  expect(keyDown(container.querySelector('a')!, 'Enter').defaultPrevented).toBe(
    false
  );
  expect(isConcealed(second!)).toBe(true);
});

it('moves focus to the link when Enter reveals a spoiler inside it', () => {
  render({ markdown: '[see ||the ending||](https://example.com)' });
  onlySpoiler().focus();

  keyDown(onlySpoiler(), 'Enter');
  expect(isConcealed(onlySpoiler())).toBe(false);
  expect(document.activeElement).toBe(container.querySelector('a'));
});

it('keeps an inline image in a spoiler with text unpressable until revealed', () => {
  render({
    markdown: '||photo ![tree](https://example.com/tree.png) here||',
    markdownStyle: { spoiler: { color: 'rgb(1, 2, 3)' } },
    onImagePress: jest.fn(),
  });

  const spoiler = onlySpoiler();
  const img = container.querySelector('img')!;
  // Inline beside its text, as on native (#1081), so the cover stays inline.
  expect(img.style.display).not.toBe('block');
  expect(spoiler.style.display).not.toBe('block');
  expect(spoiler.style.backgroundColor).toBe('rgb(1, 2, 3)');
  expect(img.hasAttribute('role')).toBe(false);

  press(spoiler);
  expect(isConcealed(spoiler)).toBe(false);
  expect(container.querySelector('img')!.getAttribute('role')).toBe('button');
});

it('covers an images-only spoiler with a layer that cross-fades with the image', () => {
  render({
    markdown: '||![a](https://example.com/a.png)||',
    markdownStyle: {
      image: { borderRadius: 8 },
      spoiler: { color: 'rgb(1, 2, 3)', solid: { borderRadius: 3 } },
    },
  });

  const spoiler = onlySpoiler();
  const img = container.querySelector('img')!;
  const cover = img.nextElementSibling as HTMLElement;
  expect(cover.className).toBe('enrm-spoiler-image-cover');
  expect(cover.style.backgroundColor).toBe('rgb(1, 2, 3)');
  expect(cover.style.borderRadius).toBe('3px');
  expect([cover.style.opacity, img.style.opacity]).toEqual(['1', '0']);
  expect(spoiler.style.backgroundColor).toBe('transparent');

  press(img);
  expect([cover.style.opacity, img.style.opacity]).toEqual(['0', '1']);
  expect(img.style.borderRadius).toBe('8px');
});

it('keeps a revealed image inside a link as link content', () => {
  const onImagePress = jest.fn();
  const onLinkPress = jest.fn();
  render({
    markdown:
      '[||![tree](https://example.com/tree.png)||](https://example.com)',
    onImagePress,
    onLinkPress,
  });

  press(onlySpoiler());
  const img = container.querySelector('img')!;
  expect(img.hasAttribute('role')).toBe(false);
  press(img);
  expect(onImagePress).not.toHaveBeenCalled();
  expect(onLinkPress).toHaveBeenCalledTimes(1);
});
