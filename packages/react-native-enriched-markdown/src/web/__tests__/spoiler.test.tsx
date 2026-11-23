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

it('turns a spoiler mixing text and a block image into a block, so its cover spans the image', () => {
  render({
    markdown: '||photo ![a](https://example.com/a.png) here||',
    markdownStyle: { spoiler: { color: 'rgb(1, 2, 3)' } },
  });

  const spoiler = onlySpoiler();
  expect(container.querySelector('img')!.style.display).toBe('block');
  expect(spoiler.style.display).toBe('block');
  expect(spoiler.style.backgroundColor).toBe('rgb(1, 2, 3)');
  expect(isConcealed(spoiler)).toBe(true);

  press(spoiler);
  expect(spoiler.style.display).toBe('block');
  expect(isConcealed(spoiler)).toBe(false);
});

it('keeps a spoiler without a block image inline', () => {
  render({ markdown: 'a ||photo|| ![a](https://example.com/a.png) b' });
  expect(onlySpoiler().style.display).toBe('');
});

it('covers an images-only spoiler with a layer the size of the image, which fades out on reveal', () => {
  render({
    markdown: '||![a](https://example.com/a.png)||',
    markdownStyle: {
      image: { borderRadius: 8 },
      spoiler: { color: 'rgb(1, 2, 3)', solid: { borderRadius: 3 } },
    },
  });

  const spoiler = onlySpoiler();
  const img = container.querySelector('img')!;
  const cover = spoiler.querySelector<HTMLElement>(
    '.enrm-spoiler-image-cover'
  )!;
  const box = img.parentElement!;
  expect(img.style.display).toBe('block');
  expect(box.style.position).toBe('relative');
  expect(cover.parentElement).toBe(box);
  expect(cover.style.inset).toBe('0');
  expect(cover.style.backgroundColor).toBe('rgb(1, 2, 3)');
  expect(cover.style.borderRadius).toBe('3px');
  expect(cover.style.opacity).toBe('1');
  expect(img.style.opacity).toBe('0');
  expect(cover.getAttribute('aria-hidden')).toBe('true');
  expect(spoiler.style.backgroundColor).toBe('transparent');
  expect(spoiler.getAttribute('role')).toBe('button');

  press(img);
  expect(spoiler.hasAttribute('data-revealed')).toBe(true);
  expect(cover.style.opacity).toBe('0');
  expect(img.style.opacity).toBe('1');
  expect(img.style.borderRadius).toBe('8px');
  const css = document.getElementById('enrm-spoiler-reveal')?.textContent ?? '';
  expect(css).toContain(
    '.enrm-spoiler[data-revealed] .enrm-spoiler-image-cover'
  );
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
  expect(isConcealed(inner!)).toBe(true);
  expect(onLinkPress).not.toHaveBeenCalled();

  const [, innerAfter] = spoilers();
  expect(innerAfter!.getAttribute('role')).toBe('button');
  expect(innerAfter!.getAttribute('tabindex')).toBe('0');
  press(innerAfter!);
  expect(isConcealed(innerAfter!)).toBe(false);
  expect(onLinkPress).not.toHaveBeenCalled();
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
