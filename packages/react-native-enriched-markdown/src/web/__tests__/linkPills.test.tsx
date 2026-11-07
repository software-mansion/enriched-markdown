/**
 * @jest-environment jsdom
 */
import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { normalizeMarkdownStyle } from '../../normalizeMarkdownStyle.web';
import type { MarkdownStyle } from '../../types/MarkdownStyle';
import type { LinkPillContent } from '../../types/linkPill';
import { RenderNode } from '../renderers';
import { buildStyles } from '../styles';
import type { ASTNode } from '../types';

(
  globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }
).IS_REACT_ACT_ENVIRONMENT = true;

const markdownStyle: MarkdownStyle = {
  linkVariants: {
    '^cite:': {
      underline: true,
      backgroundColor: '#EFF6FF',
      pill: {
        label: 'source',
        iconUri: 'https://example.com/book.png',
        lineHeight: 40,
      },
    },
  },
};

const text = (content: string): ASTNode => ({ type: 'Text', content });

const link = (url: string, children: ASTNode[]): ASTNode => ({
  type: 'Link',
  attributes: { url },
  children,
});

let container: HTMLDivElement;
let root: Root;

beforeEach(() => {
  container = document.createElement('div');
  document.body.appendChild(container);
  root = createRoot(container);
});

afterEach(() => {
  act(() => root.unmount());
  container.remove();
});

function render(
  children: ASTNode[],
  {
    linkPillContent,
    onLinkPress,
  }: {
    linkPillContent?: Record<string, LinkPillContent>;
    onLinkPress?: (event: { url: string }) => void;
  } = {}
) {
  const style = normalizeMarkdownStyle(markdownStyle);
  act(() =>
    root.render(
      <RenderNode
        node={{ type: 'Paragraph', children }}
        style={style}
        styles={buildStyles(style)}
        callbacks={{ onLinkPress }}
        capabilities={{
          katex: null,
          enableTaskListItemToggle: true,
          blockDir: undefined,
          linkPillContent,
        }}
      />
    )
  );
  return container.querySelector('a')!;
}

const paragraph = () => container.querySelector('p')!;

describe('web link pills', () => {
  it('shows the per-link label and reports the original URL', () => {
    const onLinkPress = jest.fn();
    const url = 'cite:https://en.wikipedia.org/wiki/Eiffel_Tower';
    const anchor = render([link(url, [text('cite')])], {
      linkPillContent: { [url]: { label: 'Wikipedia' } },
      onLinkPress,
    });

    expect(anchor.style.display).toBe('inline-flex');
    expect(anchor.textContent).toBe('Wikipedia');
    expect(anchor.getAttribute('aria-label')).toBe('Wikipedia, cite');
    // The variant's underline applies to the pill, as on native.
    expect(anchor.style.textDecoration).toBe('underline');

    act(() => anchor.click());
    expect(onLinkPress).toHaveBeenCalledWith({ url });
  });

  it('falls back to the variant label, then keeps ordinary links for images', () => {
    expect(render([link('cite:a', [text('a')])]).textContent).toBe('source');

    const withImage = render([
      link('cite:b', [{ type: 'Image', attributes: { url: 'x.png' } }]),
    ]);
    expect(withImage.style.display).not.toBe('inline-flex');
  });

  it('drops a failed icon and tries again when the source changes', () => {
    const url = 'cite:c';
    const iconFor = (iconUri: string) =>
      render([link(url, [text('c')])], {
        linkPillContent: { [url]: { iconUri } },
      }).querySelector('img');

    const failing = iconFor('https://example.com/missing.png')!;
    act(() => {
      failing.dispatchEvent(new Event('error'));
    });
    expect(container.querySelector('img')).toBeNull();

    expect(iconFor('https://example.com/avatar.png')).not.toBeNull();
  });

  it('raises the line height only of a paragraph that holds a pill', () => {
    render([text('see '), link('cite:d', [text('d')])]);
    expect(paragraph().style.lineHeight).toBe('40px');

    render([text('see '), link('https://example.com', [text('docs')])]);
    expect(paragraph().style.lineHeight).not.toBe('40px');
  });

  it('skips a source that failed for 30 seconds', () => {
    jest.useFakeTimers();
    try {
      const url = 'cite:e';
      const iconUri = 'https://example.com/flaky.png';
      const pill = () =>
        render([link(url, [text('e')])], {
          linkPillContent: { [url]: { iconUri } },
        });

      const icon = pill().querySelector('img')!;
      act(() => {
        icon.dispatchEvent(new Event('error'));
      });
      act(() => root.render(null));
      expect(pill().querySelector('img')).toBeNull();

      jest.advanceTimersByTime(30_000);
      act(() => root.render(null));
      expect(pill().querySelector('img')).not.toBeNull();
    } finally {
      jest.useRealTimers();
    }
  });
});
