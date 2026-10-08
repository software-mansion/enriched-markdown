#!/usr/bin/env node
// Verifies static/llms.txt lists every doc page, and nothing that doesn't exist.
//
// llms.txt is hand-written on purpose: it links to the rendered HTML pages (the
// same shape Pulsar and the other swmansion.com docs sites use), so there is no
// generator to keep it honest. This script is the guard - add a page without
// adding its line and CI fails.
//
// Zero dependencies, same style as check-examples.mjs. Reads the docs/ tree
// rather than the build output, so it runs without building the site.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const DOCS = path.join(ROOT, 'docs');
const LLMS = path.join(ROOT, 'static', 'llms.txt');
const SITE = 'https://docs.swmansion.com/enriched-markdown';

// Mirrors the `exclude` in docusaurus.config.js: the standalone native trees are
// not built unless SHOW_UNRELEASED_PLATFORMS is set, so they are not listed.
const HIDDEN = process.env.SHOW_UNRELEASED_PLATFORMS ? [] : ['ios', 'android'];

function walk(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      return HIDDEN.includes(path.relative(DOCS, full)) ? [] : walk(full);
    }
    return /\.mdx?$/.test(entry.name) && !entry.name.startsWith('_') ? [full] : [];
  });
}

// A page's route is its path under docs/, unless frontmatter overrides it with
// an explicit `slug:` (getting-started.mdx does).
function routeOf(file) {
  const source = fs.readFileSync(file, 'utf8');
  const frontmatter = source.match(/^---\n([\s\S]*?)\n---/);
  const slug = frontmatter?.[1].match(/^slug:\s*(\S+)/m);
  if (slug) return slug[1];
  return '/' + path.relative(DOCS, file).replace(/\.mdx?$/, '');
}

const expected = new Set(walk(DOCS).map(routeOf));

if (!fs.existsSync(LLMS)) {
  console.error(`✗ ${path.relative(ROOT, LLMS)} is missing`);
  process.exit(1);
}
const llms = fs.readFileSync(LLMS, 'utf8');
const listed = new Set(
  [...llms.matchAll(new RegExp(`${SITE}([^)\\s]*)`, 'g'))].map((m) =>
    m[1].replace(/\/$/, ''),
  ),
);

const missing = [...expected].filter((route) => !listed.has(route)).sort();
const orphaned = [...listed].filter((route) => !expected.has(route)).sort();

if (missing.length === 0 && orphaned.length === 0) {
  console.log(`✓ llms.txt lists all ${expected.size} doc pages`);
  process.exit(0);
}

console.error(
  `✗ static/llms.txt is out of sync with docs/ (${missing.length + orphaned.length} problems):\n`,
);
for (const route of missing) {
  console.error(`  ${route}\n    is a doc page with no entry in llms.txt`);
}
for (const route of orphaned) {
  console.error(`  ${route}\n    is listed in llms.txt but is not a doc page`);
}
console.error('\nAdd or remove the matching line in static/llms.txt.');
process.exit(1);
