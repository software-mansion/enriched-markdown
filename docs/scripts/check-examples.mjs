#!/usr/bin/env node
/**
 * Regression check: `src/examples/` must stay 1:1 with `docs/`.
 *
 * The rule (see CLAUDE.md, "`src/examples/` mirrors `docs/` 1:1"): every
 * interactive example lives at
 *
 *     src/examples/<platform>/<doc path without extension>/<ExampleName>.tsx
 *
 * where <platform> is the package the example targets (today always
 * `react-native`) and is not doubled for pages already under `docs/<platform>/`.
 *
 * `yarn build` only catches imports with no file. It happily builds a stale
 * example left behind at an old path, or one filed under the wrong page - which
 * is exactly what rots when a prop moves between pages. This catches those.
 *
 * Zero dependencies on purpose: it runs in CI before `yarn install`.
 */

import { readdirSync, readFileSync, statSync, existsSync } from 'node:fs';
import { join, relative, dirname, basename, extname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const DOCS = join(ROOT, 'docs');
const EXAMPLES = join(ROOT, 'src/examples');

/** Example modules any page may import, with the reason they are shared. */
const SHARED = [
  ['react-native/basics/your-first-project/FirstText', 'canonical intro snippet'],
  ['react-native/basics/your-first-project/FirstEditor', 'canonical intro snippet'],
  ['_shared/', 'shared palette imported by examples, not by pages'],
];

const isShared = (id) => SHARED.some(([p]) => (p.endsWith('/') ? id.startsWith(p) : id === p));

const errors = [];
const fail = (file, msg, hint) => errors.push({ file, msg, hint });

function walk(dir, test) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir).flatMap((name) => {
    const full = join(dir, name);
    return statSync(full).isDirectory() ? walk(full, test) : test(name) ? [full] : [];
  });
}

const stripExt = (p) => p.slice(0, -extname(p).length);

// --- collect pages and their example imports ---------------------------------
const pages = walk(DOCS, (n) => n.endsWith('.md') || n.endsWith('.mdx')).map((f) => ({
  /** e.g. "react-native/api-reference/enriched-markdown-text" */
  id: stripExt(relative(DOCS, f)),
  rel: relative(ROOT, f),
  imports: [
    ...new Set(
      [...readFileSync(f, 'utf8').matchAll(/@site\/src\/examples\/([A-Za-z0-9_\-./]+)/g)].map(
        (m) => m[1]
      )
    ),
  ],
}));
const pageIds = new Set(pages.map((p) => p.id));

// --- collect example files ---------------------------------------------------
const files = walk(EXAMPLES, (n) => n.endsWith('.tsx') || n.endsWith('.ts')).map((f) => ({
  /** e.g. "react-native/api-reference/enriched-markdown-text/Markdown" */
  id: stripExt(relative(EXAMPLES, f)),
  rel: relative(ROOT, f),
  name: basename(f),
  dir: dirname(relative(EXAMPLES, f)),
  isComponent: f.endsWith('.tsx'),
  source: readFileSync(f, 'utf8'),
}));
const fileIds = new Set(files.map((f) => f.id));

/**
 * The doc page that owns an example directory: `<platform>/<rest>` maps to
 * `docs/<platform>/<rest>` or, for cross-platform sections, `docs/<rest>`.
 */
function ownerOf(dir) {
  const rest = dir.split('/').slice(1).join('/');
  return [dir, rest].find((candidate) => candidate && pageIds.has(candidate)) ?? null;
}

// 1. every import resolves --------------------------------------------------
for (const page of pages) {
  for (const id of page.imports) {
    if (!fileIds.has(id)) {
      fail(page.rel, `imports @site/src/examples/${id}, which does not exist`,
        'the example was moved or renamed without updating the page (this also breaks `yarn build`)');
    }
  }
}

// 2. every example is owned by a real page, and imported by that page --------
const importedBy = new Map();
for (const page of pages) {
  for (const id of page.imports) {
    importedBy.set(id, [...(importedBy.get(id) ?? []), page.id]);
  }
}

for (const file of files) {
  if (isShared(file.id)) continue;

  if (file.isComponent) {
    const owner = ownerOf(file.dir);
    if (!owner) {
      fail(file.rel, `sits under src/examples/${file.dir}/, which maps to no doc page`,
        `expected docs/${file.dir}.{md,mdx} or docs/${file.dir.split('/').slice(1).join('/')}.{md,mdx}`);
      continue;
    }
    const users = importedBy.get(file.id) ?? [];
    if (!users.includes(owner)) {
      fail(file.rel, users.length
        ? `is imported by ${users.join(', ')} but not by its owning page ${owner}`
        : `is imported by no doc page (orphan)`,
        users.length
          ? 'move it into the importing page\'s example folder, or add it to SHARED in this script'
          : 'delete it, or import it from the page it documents');
    }
  } else if (file.name === 'theme.ts') {
    const siblings = files.filter((f) => f.dir === file.dir && f.isComponent);
    if (!siblings.some((f) => /from '\.\/theme'/.test(f.source))) {
      fail(file.rel, 'is a colocated theme re-export that no sibling example imports',
        'delete it, or import { defaultMarkdownStyle } from \'./theme\' in the examples');
    }
  } else {
    fail(file.rel, 'is an unexpected non-example module',
      'examples are *.tsx; shared helpers belong in src/examples/_shared/');
  }
}

// 3. a `./theme` import needs a colocated theme.ts ---------------------------
for (const file of files) {
  if (file.isComponent && /from '\.\/theme'/.test(file.source) && !fileIds.has(`${file.dir}/theme`)) {
    fail(file.rel, `imports './theme' but src/examples/${file.dir}/theme.ts is missing`,
      "add it: export { defaultMarkdownStyle } from '<relative>/_shared/markdownTheme';");
  }
}

// 4. naming -----------------------------------------------------------------
for (const file of files) {
  if (file.isComponent && !/^[A-Z][A-Za-z0-9]*\.tsx$/.test(file.name)) {
    fail(file.rel, `is not PascalCase`, 'name the file after the prop it shows: allowFontScaling -> AllowFontScaling.tsx');
  }
}

// --- report -----------------------------------------------------------------
const pad = (n) => String(n).padStart(3);
if (errors.length) {
  console.error(`\n✗ src/examples/ is out of sync with docs/ (${errors.length} problem${errors.length > 1 ? 's' : ''}):\n`);
  for (const { file, msg, hint } of errors) {
    console.error(`  ${file}\n    ${msg}\n    → ${hint}\n`);
  }
  console.error('The mapping is documented in docs/CLAUDE.md ("src/examples/ mirrors docs/ 1:1").\n');
  process.exit(1);
}

const components = files.filter((f) => f.isComponent).length;
console.log(
  `✓ examples in sync with docs: ${pad(components)} examples across ` +
    `${new Set(files.filter((f) => f.isComponent).map((f) => f.dir)).size} page folders, ` +
    `${pages.filter((p) => p.imports.length).length} pages importing them`
);
