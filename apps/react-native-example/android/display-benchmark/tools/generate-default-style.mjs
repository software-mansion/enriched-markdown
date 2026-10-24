// Writes the markdown style an Android `<EnrichedMarkdownText>` receives when the
// app passes no `markdownStyle`, as JSON, for the display benchmark to turn into
// the ReadableMap `StyleConfig` is built from.
//
// It runs the library's own normalizeMarkdownStyle from `src/`, so the benchmark
// styles documents exactly as JS would. `react-native` is replaced by a stub that
// answers Platform queries as Android and processes colors the way RN's
// processColor does there (signed 0xAARRGGBB ints).
//
//   node display-benchmark/tools/generate-default-style.mjs
//
// Needs Node 22.18+ (TypeScript type stripping) and the workspace's node_modules.
import { createRequire, register } from 'node:module';
import { writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { isMainThread } from 'node:worker_threads';

const STUB_URL = 'enriched-benchmark:react-native';

const toolsDir = dirname(fileURLToPath(import.meta.url));
const packageDir = resolve(toolsDir, '../../../../../packages/react-native-enriched-markdown');
const outputFile = resolve(toolsDir, '../src/androidTest/assets/default_style.json');

// --- Module hooks (run on Node's hooks thread) ---

export async function resolve_(specifier, context, nextResolve) {
  if (specifier === 'react-native') return { url: STUB_URL, shortCircuit: true };
  // The library's sources import siblings without an extension, as Metro allows.
  if (specifier.startsWith('.') && context.parentURL?.endsWith('.ts') && !/\.[cm]?[jt]sx?$/.test(specifier)) {
    return nextResolve(`${specifier}.ts`, context);
  }
  return nextResolve(specifier, context);
}
export { resolve_ as resolve };

export async function load(url, context, nextLoad) {
  if (url !== STUB_URL) return nextLoad(url, context);
  const normalizeColorsUrl = pathToFileURL(
    createRequire(resolve(packageDir, 'package.json')).resolve('@react-native/normalize-colors')
  ).href;
  const source = `
    import normalizeColorsModule from ${JSON.stringify(normalizeColorsUrl)};
    const normalizeColors = normalizeColorsModule.default ?? normalizeColorsModule;

    export const Platform = {
      OS: 'android',
      select: (spec) => ('android' in spec ? spec.android : 'native' in spec ? spec.native : spec.default),
    };

    // Mirrors react-native/Libraries/StyleSheet/processColor.js on Android.
    export function processColor(color) {
      if (color === undefined || color === null) return color;
      let normalized = normalizeColors(color);
      if (normalized === null || normalized === undefined) return undefined;
      if (typeof normalized !== 'number') return null;
      normalized = ((normalized << 24) | (normalized >>> 8)) >>> 0;
      return normalized | 0x0;
    }
  `;
  return { format: 'module', source, shortCircuit: true };
}

// --- Entry point ---

if (isMainThread) {
  globalThis.__DEV__ = false;
  register(import.meta.url);

  const { normalizeMarkdownStyle } = await import(
    pathToFileURL(resolve(packageDir, 'src/normalizeMarkdownStyle.ts')).href
  );
  // An empty style is what JS sends when the app sets none: the library's defaults.
  const style = normalizeMarkdownStyle({});
  writeFileSync(outputFile, `${JSON.stringify(style, null, 2)}\n`);
  console.log(`Wrote ${outputFile}`);
}
