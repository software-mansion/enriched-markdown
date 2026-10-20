#!/usr/bin/env node
/*
 * Checks the committed WASM bundle against the same golden AST dump that
 * scripts/test-core-parser.sh records for the host-compiled parser.
 *
 * packages/react-native-enriched-markdown/src/web/wasm/md4c.js is a build
 * artifact: nothing rebuilds it on install, prepare or prepack, so a change to
 * packages/core/cpp reaches native immediately and web only once someone runs
 * `yarn build:wasm`. It had been behind by a release cycle and a feature
 * (#765's video blocks) before anyone noticed. Comparing the bundle's own
 * output to the golden dump catches that without emscripten in CI.
 *
 * Usage:
 *   node scripts/test-web-bundle.mjs
 */
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const BUNDLE = join(
  REPO_ROOT,
  'packages/react-native-enriched-markdown/src/web/wasm/md4c.js'
);
const FIXTURES = join(REPO_ROOT, 'packages/core/cpp/tests/fixtures');
const GOLDEN = join(REPO_ROOT, 'packages/core/cpp/tests/golden/ast.txt');

// parseMarkdown() in md4c_wasm.cpp exposes eight of the parser's flags; isGFM
// and permissiveAutolinks keep their Md4cFlags defaults (true). That reaches
// two of the golden dump's five variants - the other three turn one of those
// two off, so they cannot be reproduced through this entry point.
const VARIANTS = {
  // underline, latexMath, superscript, subscript, highlight, hardSoftBreaks,
  // preserveBlankLines, admonitions
  'defaults-gfm': [0, 1, 0, 0, 0, 0, 0, 1],
  'extensions-on-gfm': [1, 1, 1, 1, 1, 1, 1, 1],
};

function readGolden() {
  const lines = readFileSync(GOLDEN, 'utf8').split('\n');
  const sections = new Map();
  for (let i = 0; i < lines.length - 1; i++) {
    const header = lines[i].match(/^=== (\S+) \[(\S+)\] ===$/);
    if (header) {
      sections.set(`${header[1]} [${header[2]}]`, lines[i + 1]);
    }
  }
  return sections;
}

function firstDifference(actual, expected) {
  const limit = Math.min(actual.length, expected.length);
  let at = limit;
  for (let i = 0; i < limit; i++) {
    if (actual[i] !== expected[i]) {
      at = i;
      break;
    }
  }
  const from = Math.max(0, at - 60);
  return {
    at,
    actual: actual.slice(from, at + 60),
    expected: expected.slice(from, at + 60),
  };
}

function fail(message) {
  console.error(`FAIL: ${message}`);
  console.error();
  console.error(
    'The committed bundle is a build artifact and nothing rebuilds it'
  );
  console.error('automatically. Rebuild and commit it with:');
  console.error();
  console.error('    yarn build:wasm');
  process.exit(1);
}

const golden = readGolden();
const fixtures = readdirSync(FIXTURES)
  .filter((name) => name.endsWith('.md'))
  .sort();
if (fixtures.length === 0) {
  fail(`no fixtures in ${FIXTURES}`);
}

console.log('==> Loading the committed WASM bundle');
const module = await import(pathToFileURL(BUNDLE).href);
const instance = await module.default();
const parse = instance.cwrap('parseMarkdown', 'string', [
  'string',
  ...Array(8).fill('number'),
]);

console.log('==> Comparing its AST against the golden dump');
let compared = 0;
for (const fixture of fixtures) {
  const markdown = readFileSync(join(FIXTURES, fixture), 'utf8');
  for (const [variant, flags] of Object.entries(VARIANTS)) {
    const section = `${fixture} [${variant}]`;
    const expected = golden.get(section);
    if (expected === undefined) {
      fail(
        `the golden dump has no "${section}" section. Re-record it with ` +
          './scripts/test-core-parser.sh --update, or update VARIANTS here.'
      );
    }
    const actual = parse(markdown, ...flags);
    if (actual !== expected) {
      const diff = firstDifference(actual, expected);
      console.error(`FAIL: the bundle disagrees with the C++ parser on`);
      console.error(`      ${section}, at character ${diff.at}:`);
      console.error();
      console.error(`  bundle: …${diff.actual}…`);
      console.error(`  golden: …${diff.expected}…`);
      console.error();
      fail(`${section} does not match the golden dump`);
    }
    compared++;
  }
}

console.log(`    ${compared} fixture/flag combinations match`);
console.log();
console.log('PASS');
