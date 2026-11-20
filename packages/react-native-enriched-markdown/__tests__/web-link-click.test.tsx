import type { ReactElement, MouseEvent } from 'react';
import { inlineRenderers } from '../src/web/renderers/InlineRenderers';
import { normalizeMarkdownStyle } from '../src/normalizeMarkdownStyle.web';
import { buildStyles } from '../src/web/styles';
import type { ASTNode, RendererProps } from '../src/web/types';

type ClickInit = Partial<
  Pick<MouseEvent, 'metaKey' | 'ctrlKey' | 'shiftKey' | 'altKey' | 'button'>
>;

function renderLink(url: string, onLinkPress?: jest.Mock) {
  const node: ASTNode = { type: 'Link', children: [], attributes: { url } };
  const style = normalizeMarkdownStyle({});
  const props = {
    node,
    style,
    styles: buildStyles(style),
    callbacks: { onLinkPress },
    capabilities: {},
    renderChildren: () => null,
  } as unknown as RendererProps;
  const link = inlineRenderers.Link as unknown as (
    props: RendererProps
  ) => ReactElement<{ onClick: (event: MouseEvent) => void }>;

  return link(props).props.onClick;
}

function click(onClick: (event: MouseEvent) => void, init: ClickInit = {}) {
  const event = {
    metaKey: false,
    ctrlKey: false,
    shiftKey: false,
    altKey: false,
    button: 0,
    preventDefault: jest.fn(),
    ...init,
  } as unknown as MouseEvent;
  onClick(event);
  return event;
}

describe('web LinkRenderer click handling with onLinkPress', () => {
  it('sends a plain primary click to onLinkPress and cancels the navigation', () => {
    const onLinkPress = jest.fn();
    const event = click(renderLink('https://example.com', onLinkPress));

    expect(onLinkPress).toHaveBeenCalledWith({ url: 'https://example.com' });
    expect(event.preventDefault).toHaveBeenCalled();
  });

  it.each([
    ['cmd-click', { metaKey: true }],
    ['ctrl-click', { ctrlKey: true }],
    ['shift-click', { shiftKey: true }],
    ['alt-click', { altKey: true }],
    ['non-primary button', { button: 1 }],
  ])('leaves a %s on a web link to the browser', (_name, init) => {
    const onLinkPress = jest.fn();
    const event = click(renderLink('https://example.com', onLinkPress), init);

    expect(onLinkPress).not.toHaveBeenCalled();
    expect(event.preventDefault).not.toHaveBeenCalled();
  });

  it.each(['mailto:a@b.co', '/docs', '#section', '?page=2'])(
    'leaves a modified click on %s to the browser',
    (url) => {
      const onLinkPress = jest.fn();
      click(renderLink(url, onLinkPress), { metaKey: true });

      expect(onLinkPress).not.toHaveBeenCalled();
    }
  );

  it('still sends a modified click on a link the browser cannot open to onLinkPress', () => {
    const onLinkPress = jest.fn();
    const event = click(renderLink('user://42', onLinkPress), {
      metaKey: true,
    });

    expect(onLinkPress).toHaveBeenCalledWith({ url: 'user://42' });
    expect(event.preventDefault).toHaveBeenCalled();
  });

  it('does nothing without onLinkPress', () => {
    const event = click(renderLink('https://example.com'));

    expect(event.preventDefault).not.toHaveBeenCalled();
  });
});
