import { normalizeMarkdownStyle } from '../src/normalizeMarkdownStyle';
import { normalizeMarkdownStyle as normalizeWebStyle } from '../src/normalizeMarkdownStyle.web';
import { normalizeColor } from '../src/styleUtils';

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
    pill: false,
    label: '',
    iconUri: '',
    borderRadius: 8,
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderWidth: 0,
    borderColor: normalizeColor('transparent'),
    maxWidth: 0,
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
    pill: true,
    label: 'Example',
    iconUri: 'file:///bundle/icon.png',
    fontFamily: 'Custom',
    paddingHorizontal: 12,
    paddingVertical: 3,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: normalizeColor('#123456'),
    maxWidth: 160,
  });
  expect(style.linkVariants[1]?.label).toBe('');
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
  expect(style.linkVariants[0]).toMatchObject({
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
    pill: true,
    label: 'visual',
    fontFamily: 'Custom',
    borderColor: 'transparent',
    maxWidth: 120,
  });
});

it.each([undefined, false, null])('keeps pills disabled for %s', (pill) => {
  expect(
    normalizeMarkdownStyle({ linkVariants: { '^app:': { pill } } })
      .linkVariants[0]
  ).toMatchObject({ pill: false, label: '', paddingHorizontal: 6 });
});

it.each([true, {}])('enables default presentation for %s', (pill) => {
  expect(
    normalizeMarkdownStyle({ linkVariants: { '^app:': { pill } } })
      .linkVariants[0]
  ).toMatchObject({ pill: true, label: '', paddingHorizontal: 6 });
});
