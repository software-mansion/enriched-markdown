import { normalizeMarkdownStyle } from '../src/normalizeMarkdownStyle';
import { normalizeMarkdownStyle as normalizeWebStyle } from '../src/normalizeMarkdownStyle.web';
import { normalizeColor } from '../src/styleUtils';
import {
  isLinkPillContentEqual,
  normalizeLinkPillContent,
} from '../src/linkVariantUtils';

it('requires an explicit pill opt-in and preserves ordinary link overrides', () => {
  const style = normalizeMarkdownStyle({
    link: { color: '#112233', underline: false, fontFamily: 'Example' },
    linkVariants: {
      '^https:': { backgroundColor: '#abcdef' },
    },
  });
  expect(style.linkVariants[0]).toEqual({
    pattern: '^https:',
    color: normalizeColor('#112233'),
    underline: false,
    backgroundColor: normalizeColor('#abcdef'),
    fontFamily: 'Example',
    pill: {
      enabled: false,
      label: '',
      iconUri: '',
      borderRadius: 8,
      paddingHorizontal: 6,
      paddingVertical: 2,
      lineHeight: 0,
      borderWidth: 0,
      borderColor: normalizeColor('transparent'),
      maxWidth: 0,
    },
  });
});

it('normalizes presentation fields and orders specific URL patterns first', () => {
  const style = normalizeMarkdownStyle({
    linkVariants: {
      '^https:': { pill: true },
      '^https://example.com/': {
        fontFamily: 'Custom',
        pill: {
          label: 'Example',
          iconUri: 'file:///bundle/icon.png',
          paddingHorizontal: 12,
          paddingVertical: 3,
          borderRadius: 10,
          borderWidth: 1,
          borderColor: '#123456',
          maxWidth: 160,
        },
      },
    },
  });
  expect(style.linkVariants[0]).toMatchObject({
    pattern: '^https://example.com/',
    fontFamily: 'Custom',
    pill: {
      enabled: true,
      label: 'Example',
      iconUri: 'file:///bundle/icon.png',
      paddingHorizontal: 12,
      paddingVertical: 3,
      borderRadius: 10,
      borderWidth: 1,
      borderColor: normalizeColor('#123456'),
      maxWidth: 160,
    },
  });
  expect(style.linkVariants[1]?.pill.label).toBe('');
});

it('rejects nonfinite geometry, clamps negatives, and preserves explicit zero', () => {
  const style = normalizeMarkdownStyle({
    linkVariants: {
      '^app:': {
        pill: {
          paddingHorizontal: Infinity,
          paddingVertical: -1,
          borderRadius: NaN,
          borderWidth: 0,
          maxWidth: -200,
        },
      },
    },
  });
  expect(style.linkVariants[0]?.pill).toMatchObject({
    paddingHorizontal: 6,
    paddingVertical: 0,
    borderRadius: 8,
    borderWidth: 0,
    maxWidth: 0,
  });
});

it('keeps the previous transparent variant background fallback', () => {
  const style = normalizeMarkdownStyle({
    link: { backgroundColor: '#ffffff' },
    linkVariants: { '^app:': {} },
  });
  expect(style.linkVariants[0]?.backgroundColor).toBe(
    normalizeColor('transparent')
  );
});

it('ignores invalid patterns with the existing warning', () => {
  const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  const style = normalizeMarkdownStyle({
    linkVariants: { '[': { pill: true }, '^valid:': { pill: true } },
  });
  expect(style.linkVariants.map((entry) => entry.pattern)).toEqual(['^valid:']);
  expect(warn).toHaveBeenCalledWith(
    expect.stringContaining('not a valid regex')
  );
  warn.mockRestore();
});

it('normalizes nested web configuration without changing document labels', () => {
  const style = normalizeWebStyle({
    linkVariants: {
      '^app:': {
        fontFamily: 'Custom',
        pill: { label: 'visual', maxWidth: 120 },
      },
    },
  });
  expect(style.linkVariants[0]).toMatchObject({
    fontFamily: 'Custom',
    pill: {
      enabled: true,
      label: 'visual',
      borderColor: 'transparent',
      maxWidth: 120,
    },
  });
});

it.each([undefined, false])('keeps pills disabled for %s', (pill) => {
  expect(
    normalizeMarkdownStyle({ linkVariants: { '^app:': { pill } } })
      .linkVariants[0]?.pill
  ).toMatchObject({ enabled: false, label: '', paddingHorizontal: 6 });
});

it.each([true, {}])('enables default presentation for %s', (pill) => {
  expect(
    normalizeMarkdownStyle({ linkVariants: { '^app:': { pill } } })
      .linkVariants[0]?.pill
  ).toMatchObject({ enabled: true, label: '', paddingHorizontal: 6 });
});

it('returns the cached style for a structurally equal inline nested pill', () => {
  const make = () => ({
    linkVariants: { '^cache:': { color: '#112233', pill: { label: 'Doc' } } },
  });
  expect(normalizeMarkdownStyle(make())).toBe(normalizeMarkdownStyle(make()));
  expect(normalizeMarkdownStyle(make())).not.toBe(
    normalizeMarkdownStyle({
      linkVariants: { '^cache:': { color: '#112233', pill: { label: 'X' } } },
    })
  );
});

it('flattens per-link pill content into a stable, sorted native array', () => {
  expect(normalizeLinkPillContent(undefined)).toBeUndefined();
  expect(
    normalizeLinkPillContent({
      'user:b': { iconUri: 'avatar_b' },
      'https://example.com/a': { label: 'a.ts' },
    })
  ).toEqual([
    { url: 'https://example.com/a', label: 'a.ts', iconUri: '' },
    { url: 'user:b', label: '', iconUri: 'avatar_b' },
  ]);
});

it('treats structurally equal per-link content as unchanged', () => {
  const make = (label: string) =>
    normalizeLinkPillContent({ 'https://example.com/a': { label } });
  expect(isLinkPillContentEqual(make('a.ts'), make('a.ts'))).toBe(true);
  expect(isLinkPillContentEqual(make('a.ts'), make('b.ts'))).toBe(false);
  expect(isLinkPillContentEqual(undefined, undefined)).toBe(true);
  expect(isLinkPillContentEqual(undefined, make('a.ts'))).toBe(false);
});
