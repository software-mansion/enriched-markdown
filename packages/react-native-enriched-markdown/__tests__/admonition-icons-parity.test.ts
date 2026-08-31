/**
 * Cross-platform parity guard for the GitHub admonition/alert header assets.
 *
 * The octicon `d` path strings, the header titles and the icon viewBox are
 * duplicated verbatim in three renderers because each runtime parses them with
 * its own API (iOS CGPath, Android PathParser, web SVG DOM) and there is no
 * shared runtime between them. The web file is the single source of truth; this
 * test reads the iOS and Android sources as text and asserts they stay
 * byte-identical to it, so a one-sided edit or typo fails CI instead of shipping
 * a mismatched glyph.
 *
 * This runs under `yarn test` (jest) in the `rn-lint` CI job, which fires
 * whenever anything under packages/react-native-enriched-markdown/** changes -
 * that glob currently contains all three copies, so any edit to any copy is
 * covered. If the native sources ever move out of this package, this guard no
 * longer sees them: re-home it (or add a native-side check) at that point. The
 * hardcoded paths below are resolved eagerly so a moved/renamed file fails loud
 * rather than silently passing.
 */
import { readFileSync } from 'fs';
import { join } from 'path';
import {
  ADMONITION_ICON_PATHS,
  ADMONITION_TITLES,
  ADMONITION_ICON_VIEWBOX,
} from '../src/web/renderers/admonitionIcons';

const PKG_ROOT = join(__dirname, '..');
const IOS_FILE = join(PKG_ROOT, 'ios/segments/ENRMAdmonitionIcons.m');
const ANDROID_FILE = join(
  PKG_ROOT,
  'android/src/main/java/com/swmansion/enriched/markdown/segments/AdmonitionIcons.kt'
);

const KEYS = ['note', 'tip', 'important', 'warning', 'caution'] as const;

function read(path: string): string {
  try {
    return readFileSync(path, 'utf8');
  } catch {
    throw new Error(
      `Admonition icon source not found at ${path}. If it moved, update this ` +
        `parity guard (see the file header) so it keeps checking all copies.`
    );
  }
}

function slice(src: string, from: string, to: string): string {
  const start = src.indexOf(from);
  const end = src.indexOf(to, start + from.length);
  if (start === -1 || end === -1) {
    throw new Error(`Could not locate block "${from}"..."${to}"`);
  }
  return src.slice(start, end);
}

// Reconstructs a string map from a block of `<open>value<close>` literal
// entries, joining Objective-C's multi-literal continuations (@"a" @"b").
function parseEntries(
  block: string,
  entryRe: RegExp,
  literalRe: RegExp
): Record<string, string> {
  const out: Record<string, string> = {};
  for (const m of block.matchAll(entryRe)) {
    const key = m[1];
    const body = m[2];
    if (key === undefined || body === undefined) continue;
    out[key] = [...body.matchAll(literalRe)].map((l) => l[1] ?? '').join('');
  }
  return out;
}

function num(src: string, re: RegExp): number {
  const match = src.match(re)?.[1];
  if (match === undefined) throw new Error(`No numeric match for ${re}`);
  return Number(match);
}

function parseObjC(src: string) {
  const entryRe = /@"([^"]+)"\s*:\s*((?:@"[^"]*"\s*)+)/g;
  const literalRe = /@"([^"]*)"/g;
  return {
    paths: parseEntries(slice(src, 'data = @{', '};'), entryRe, literalRe),
    titles: parseEntries(slice(src, 'titles = @{', '};'), entryRe, literalRe),
    viewBox: num(src, /ENRMAdmonitionIconViewBox\s*=\s*([\d.]+)/),
  };
}

function parseKotlin(src: string) {
  const entryRe = /"([^"]+)"\s+to\s+((?:"[^"]*"\s*)+)/g;
  const literalRe = /"([^"]*)"/g;
  return {
    paths: parseEntries(
      slice(src, 'PATH_DATA =', 'TITLES'),
      entryRe,
      literalRe
    ),
    titles: parseEntries(
      slice(src, 'TITLES =', 'fun path'),
      entryRe,
      literalRe
    ),
    viewBox: num(src, /VIEWBOX\s*=\s*([\d.]+)f?/),
  };
}

describe('admonition icon assets stay in sync across platforms', () => {
  const ios = parseObjC(read(IOS_FILE));
  const android = parseKotlin(read(ANDROID_FILE));

  it.each(KEYS)('icon path "%s" is identical web/iOS/Android', (key) => {
    const web = ADMONITION_ICON_PATHS[key];
    expect(web).toBeTruthy();
    expect(ios.paths[key]).toBe(web);
    expect(android.paths[key]).toBe(web);
  });

  it.each(KEYS)('title "%s" is identical web/iOS/Android', (key) => {
    const web = ADMONITION_TITLES[key];
    expect(ios.titles[key]).toBe(web);
    expect(android.titles[key]).toBe(web);
  });

  it('viewBox is identical web/iOS/Android', () => {
    expect(ios.viewBox).toBe(ADMONITION_ICON_VIEWBOX);
    expect(android.viewBox).toBe(ADMONITION_ICON_VIEWBOX);
  });

  it('each platform declares exactly the web set of keys (no extras/missing)', () => {
    const expected = [...KEYS].sort();
    expect(Object.keys(ADMONITION_ICON_PATHS).sort()).toEqual(expected);
    expect(Object.keys(ios.paths).sort()).toEqual(expected);
    expect(Object.keys(android.paths).sort()).toEqual(expected);
    expect(Object.keys(ios.titles).sort()).toEqual(expected);
    expect(Object.keys(android.titles).sort()).toEqual(expected);
  });
});
