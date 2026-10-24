import { normalizeMarkdownStyle } from '../src/normalizeMarkdownStyle';
import { normalizeMarkdownStyle as normalizeWebStyle } from '../src/normalizeMarkdownStyle.web';
import { linkStyleForUrl } from '../src/web/styles';

it.each([normalizeMarkdownStyle, normalizeWebStyle])(
  'inherits the base link family and permits a per-variant override',
  (normalize) => {
    const style = normalize({
      link: { fontFamily: 'Base' },
      linkVariants: {
        '^https:': {},
        '^https://example.com/': { fontFamily: 'Custom' },
      },
    });
    expect(style.linkVariants.map((variant) => variant.fontFamily)).toEqual([
      'Custom',
      'Base',
    ]);
  }
);

it('uses the matching variant font for ordinary web links', () => {
  const style = normalizeWebStyle({
    link: { fontFamily: 'Base' },
    linkVariants: { '^https:': { fontFamily: 'Custom' } },
  });
  expect(linkStyleForUrl(style, 'https://example.com').fontFamily).toBe(
    'Custom'
  );
});
