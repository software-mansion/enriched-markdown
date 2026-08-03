#!/usr/bin/env node
// Copies the tree-sitter runtime and each supported grammar's minimal source set
// into packages/core/cpp/highlight/vendor/. Two modes:
//
//   node vendor/vendor-grammars.mjs                 (maintainer, on re-pin)
//     Refreshes the runtime, every grammar, and the committed default registry.
//     The runtime (tree-sitter/) and registry (generated/) are TRACKED in git;
//     commit them after a re-pin. Requires the tree-sitter runtime source (see
//     --runtime-src / TREE_SITTER_SRC).
//
//   node vendor/vendor-grammars.mjs --grammars-only  (install + prepack, wired
//     into `prepare` and prepare-npm-publish.sh)
//     Restores ONLY grammars/ (34 MB, gitignored) from the grammar
//     devDependencies; leaves the committed runtime + registry untouched. A
//     .stamp fingerprint makes it a no-op when the vendored set already matches
//     the pinned versions, so repeated `yarn install`s do not rewrite it. Pass
//     --force to rebuild regardless.
//
// Flags: [--only json,css] [--runtime-src <lib dir>] [--grammars-only] [--force]
//
// Only parser.c, scanner.c (when present), tree_sitter/*.h, highlights.scm and
// LICENSE are copied; nothing else from the grammar packages ships. WASM is left
// out of the runtime by never defining TREE_SITTER_FEATURE_WASM at build time,
// so the full lib/src tree (including wasm_store.c and its no-op stubs) is
// vendored verbatim and only lib.c is compiled.

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { spawnSync, } from 'node:child_process';
import { createRequire } from 'node:module';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..');
const vendorOut = path.join(repoRoot, 'packages/core/cpp/highlight/vendor');
const manifestPath = path.join(here, 'grammar-versions.json');

// Grammar packages are devDependencies of react-native-enriched-markdown, so
// resolve them from that workspace regardless of hoisting.
const pkgRequire = createRequire(
  path.join(repoRoot, 'packages/react-native-enriched-markdown/package.json')
);

function parseArgs(argv) {
  const args = { only: null, runtimeSrc: null, grammarsOnly: false, force: false };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--only') args.only = argv[++i].split(',').map((s) => s.trim());
    else if (argv[i] === '--runtime-src') args.runtimeSrc = argv[++i];
    else if (argv[i] === '--grammars-only') args.grammarsOnly = true;
    else if (argv[i] === '--force') args.force = true;
  }
  return args;
}

function fail(message) {
  console.error(`[vendor-grammars] ${message}`);
  process.exit(1);
}

function copyFile(src, dest) {
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(src, dest);
}

function copyDir(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const from = path.join(src, entry.name);
    const to = path.join(dest, entry.name);
    if (entry.isDirectory()) copyDir(from, to);
    else copyFile(from, to);
  }
}

function firstExisting(candidates) {
  return candidates.find((p) => p && fs.existsSync(p)) ?? null;
}

function resolveRuntimeSrc(runtimeSrcArg) {
  const candidates = [
    runtimeSrcArg,
    process.env.TREE_SITTER_SRC,
    path.join(repoRoot, 'node_modules/tree-sitter/vendor/tree-sitter/lib'),
  ].filter(Boolean);
  const libDir = firstExisting(candidates);
  if (!libDir) {
    fail(
      'tree-sitter runtime source not found. Pass --runtime-src <path to tree-sitter/lib> ' +
        'or set TREE_SITTER_SRC. Expected a directory containing src/lib.c and include/tree_sitter/api.h.'
    );
  }
  return libDir;
}

function vendorRuntime(libDir) {
  const srcDir = path.join(libDir, 'src');
  const apiHeader = path.join(libDir, 'include/tree_sitter/api.h');
  if (!fs.existsSync(path.join(srcDir, 'lib.c')) || !fs.existsSync(apiHeader)) {
    fail(`runtime source at ${libDir} is missing src/lib.c or include/tree_sitter/api.h`);
  }
  const outSrc = path.join(vendorOut, 'tree-sitter/src');
  fs.rmSync(outSrc, { recursive: true, force: true });
  copyDir(srcDir, outSrc);
  copyFile(apiHeader, path.join(vendorOut, 'tree-sitter/include/tree_sitter/api.h'));
  console.log(`[vendor-grammars] runtime -> ${path.relative(repoRoot, outSrc)}`);
}

function packageRoot(pkgName) {
  try {
    return path.dirname(pkgRequire.resolve(`${pkgName}/package.json`));
  } catch {
    fail(`grammar package ${pkgName} not installed. Add it as a devDependency and run yarn install.`);
    return '';
  }
}

// Resolves a grammar's highlights.scm from its package (null if it ships none).
// A grammar with no highlights query cannot be compiled into the registry, so
// callers skip it. Kept separate so main() can pre-filter without side effects.
function grammarHighlights(spec) {
  const pkgRoot = packageRoot(spec.package);
  const base = spec.subPath ? path.join(pkgRoot, spec.subPath) : pkgRoot;
  return firstExisting([
    path.join(base, 'queries/highlights.scm'),
    path.join(pkgRoot, 'queries/highlights.scm'),
  ]);
}

function vendorGrammar(id, spec) {
  const pkgRoot = packageRoot(spec.package);
  const base = spec.subPath ? path.join(pkgRoot, spec.subPath) : pkgRoot;
  const srcDir = path.join(base, 'src');
  const outDir = path.join(vendorOut, 'grammars', id);

  const parser = path.join(srcDir, 'parser.c');
  if (!fs.existsSync(parser)) fail(`${id}: parser.c not found at ${parser}`);

  if (spec.scanner && !fs.existsSync(path.join(srcDir, 'scanner.c'))) {
    fail(`${id}: scanner:true but scanner.c missing at ${srcDir}`);
  }

  // Resolve highlights before writing anything so a highlights-less grammar
  // never leaves a partial output dir (main() filters these out up front).
  const highlights = grammarHighlights(spec);
  if (!highlights) fail(`${id}: queries/highlights.scm not found under ${base} or ${pkgRoot}`);

  fs.rmSync(outDir, { recursive: true, force: true });

  // Copy every loose .c/.h in src/ (parser.c, scanner.c, plus siblings a scanner
  // text-includes such as html's tag.h or yaml's schema.*.c). Only parser.c and
  // scanner.c are compiled; the rest are include-only. node-types.json,
  // grammar.json and other non-source files are left behind.
  for (const entry of fs.readdirSync(srcDir, { withFileTypes: true })) {
    if (entry.isFile() && /\.(c|h)$/.test(entry.name)) {
      copyFile(path.join(srcDir, entry.name), path.join(outDir, entry.name));
    }
  }

  const headerDir = path.join(srcDir, 'tree_sitter');
  if (fs.existsSync(headerDir)) copyDir(headerDir, path.join(outDir, 'tree_sitter'));

  copyFile(highlights, path.join(outDir, 'highlights.scm'));

  const license = firstExisting([
    path.join(pkgRoot, 'LICENSE'),
    path.join(pkgRoot, 'LICENSE.md'),
    path.join(pkgRoot, 'LICENSE.txt'),
  ]);
  if (license) copyFile(license, path.join(outDir, 'LICENSE'));

  console.log(`[vendor-grammars] ${id} -> ${path.relative(repoRoot, outDir)}`);
}

function regenerateDefaultRegistry(manifest) {
  const defaults = Object.entries(manifest.grammars)
    .filter(([, spec]) => spec.default)
    .map(([id]) => id);
  const outDir = path.join(vendorOut, 'generated');
  const result = spawnSync(
    process.execPath,
    [
      path.join(here, 'gen-registry.mjs'),
      '--vendor-dir',
      vendorOut,
      '--languages',
      defaults.join(','),
      '--out',
      outDir,
    ],
    { stdio: 'inherit' }
  );
  if (result.status !== 0) fail('gen-registry.mjs failed while refreshing the committed default set');
}

function requireSpec(manifest, id) {
  const spec = manifest.grammars[id];
  if (!spec) fail(`unknown grammar '${id}' (not in grammar-versions.json)`);
  return spec;
}

// Fingerprint of the pinned grammar set: manifest spec plus each grammar
// package's installed version, so a re-pin OR a node_modules change invalidates.
function grammarStampKey(manifest, ids) {
  const parts = ids.map((id) => {
    const spec = requireSpec(manifest, id);
    let version = 'missing';
    try {
      version = pkgRequire(`${spec.package}/package.json`).version;
    } catch {
      /* resolved lazily during copy; a miss just forces a rebuild */
    }
    return `${id}|${spec.package}@${version}|scanner:${!!spec.scanner}|sub:${spec.subPath ?? ''}`;
  });
  return crypto.createHash('sha256').update(JSON.stringify(parts)).digest('hex');
}

function everyGrammarPresent(ids) {
  return ids.every((id) => fs.existsSync(path.join(vendorOut, 'grammars', id, 'parser.c')));
}

function readStamp(stampFile) {
  return fs.existsSync(stampFile) ? fs.readFileSync(stampFile, 'utf8').trim() : null;
}

// Drops grammars whose package ships no highlights.scm (they cannot be compiled
// into any registry). A default-set grammar missing one is a hard error; others
// are skipped with a warning and any stale output removed.
function vendorableIds(manifest, ids) {
  const out = [];
  for (const id of ids) {
    const spec = requireSpec(manifest, id);
    if (grammarHighlights(spec)) {
      out.push(id);
    } else if (spec.default) {
      fail(`${id} is in the default set but its package ships no queries/highlights.scm`);
    } else {
      fs.rmSync(path.join(vendorOut, 'grammars', id), { recursive: true, force: true });
      console.warn(`[vendor-grammars] ${id}: package ships no highlights.scm; skipping (non-default, not compilable).`);
    }
  }
  return out;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  const requested = args.only ?? Object.keys(manifest.grammars);
  const ids = vendorableIds(manifest, requested);
  const stampFile = path.join(vendorOut, 'grammars', '.stamp');
  // Only a full-set run may trust or write the stamp; a partial --only run must not.
  const stampKey = args.only ? null : grammarStampKey(manifest, ids);

  if (args.grammarsOnly) {
    // Install/prepack path: the runtime and default registry are committed, so
    // only restore the gitignored grammar sources from the devDependencies. Skip
    // entirely when the vendored set already matches the pinned versions, so a
    // plain `yarn install` does not rewrite 34 MB on every run.
    if (!args.force && stampKey && everyGrammarPresent(ids) && readStamp(stampFile) === stampKey) {
      console.log('[vendor-grammars] grammar sources already up to date; skipping.');
      return;
    }
    for (const id of ids) vendorGrammar(id, requireSpec(manifest, id));
    if (stampKey) fs.writeFileSync(stampFile, stampKey + '\n');
    console.log('[vendor-grammars] grammar sources ready.');
    return;
  }

  // Maintainer full run (re-pin in grammar-versions.json): refresh the runtime,
  // every grammar, and the committed default registry.
  vendorRuntime(resolveRuntimeSrc(args.runtimeSrc));
  for (const id of ids) vendorGrammar(id, requireSpec(manifest, id));
  regenerateDefaultRegistry(manifest);
  if (stampKey) fs.writeFileSync(stampFile, stampKey + '\n');
  console.log(
    '[vendor-grammars] done. Commit the runtime + generated registry under ' +
      'packages/core/cpp/highlight/vendor/ (grammars/ is gitignored).'
  );
}

main();
