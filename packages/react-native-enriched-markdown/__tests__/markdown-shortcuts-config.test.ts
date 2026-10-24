/**
 * The native side receives a complete object — Android's `ReadableMap.getBoolean`
 * throws on a missing or non-boolean field — so every public shorthand has to
 * normalize to three real booleans here.
 */
import { normalizeMarkdownShortcuts } from '../src/normalizeMarkdownShortcuts';

const ALL_OFF = { heading: false, unorderedList: false, orderedList: false };
const ALL_ON = { heading: true, unorderedList: true, orderedList: true };

describe('normalizeMarkdownShortcuts', () => {
  it('defaults to off when the prop is omitted', () => {
    expect(normalizeMarkdownShortcuts(undefined)).toEqual(ALL_OFF);
  });

  it('treats the boolean shorthand as all-or-nothing', () => {
    expect(normalizeMarkdownShortcuts(true)).toEqual(ALL_ON);
    expect(normalizeMarkdownShortcuts(false)).toEqual(ALL_OFF);
  });

  it('enables only the families named in a config object', () => {
    expect(normalizeMarkdownShortcuts({ heading: true })).toEqual({
      ...ALL_OFF,
      heading: true,
    });
    expect(
      normalizeMarkdownShortcuts({ unorderedList: true, orderedList: true })
    ).toEqual({ ...ALL_ON, heading: false });
  });

  it('honors an explicit false alongside an enabled family', () => {
    expect(
      normalizeMarkdownShortcuts({ heading: true, orderedList: false })
    ).toEqual({ ...ALL_OFF, heading: true });
  });

  it('falls back to off for values the type system cannot stop', () => {
    expect(normalizeMarkdownShortcuts(null)).toEqual(ALL_OFF);
    expect(normalizeMarkdownShortcuts('yes')).toEqual(ALL_OFF);
    expect(normalizeMarkdownShortcuts({ heading: 'yes' })).toEqual(ALL_OFF);
    expect(normalizeMarkdownShortcuts({ heading: undefined })).toEqual(ALL_OFF);
  });
});
