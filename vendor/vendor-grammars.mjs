#!/usr/bin/env node
// Maintainer-run: copies the tree-sitter runtime and each supported grammar's
// minimal source set into packages/core/cpp/highlight/vendor/, then regenerates
// the committed default-set registry. Run after `yarn install` (grammar packages
// are devDependencies) whenever grammar-versions.json changes.
//
//   node vendor/vendor-grammars.mjs [--only json,css] [--runtime-src <lib dir>]
//
// Only parser.c, scanner.c (when present), tree_sitter/*.h, highlights.scm and
// LICENSE are copied; nothing else from the grammar packages ships. WASM is left
// out of the runtime by never defining TREE_SITTER_FEATURE_WASM at build time,
// so the full lib/src tree (including wasm_store.c and its no-op stubs) is
// vendored verbatim and only lib.c is compiled.

import fs from 'node:fs';
import path from 'node:path';
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
  const args = { only: null, runtimeSrc: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--only') args.only = argv[++i].split(',').map((s) => s.trim());
    else if (argv[i] === '--runtime-src') args.runtimeSrc = argv[++i];
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

function vendorGrammar(id, spec) {
  const pkgRoot = packageRoot(spec.package);
  const base = spec.subPath ? path.join(pkgRoot, spec.subPath) : pkgRoot;
  const srcDir = path.join(base, 'src');
  const outDir = path.join(vendorOut, 'grammars', id);
  fs.rmSync(outDir, { recursive: true, force: true });

  const parser = path.join(srcDir, 'parser.c');
  if (!fs.existsSync(parser)) fail(`${id}: parser.c not found at ${parser}`);

  if (spec.scanner && !fs.existsSync(path.join(srcDir, 'scanner.c'))) {
    fail(`${id}: scanner:true but scanner.c missing at ${srcDir}`);
  }

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

  const highlights = firstExisting([
    path.join(base, 'queries/highlights.scm'),
    path.join(pkgRoot, 'queries/highlights.scm'),
  ]);
  if (!highlights) fail(`${id}: queries/highlights.scm not found under ${base} or ${pkgRoot}`);
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

function main() {
  const args = parseArgs(process.argv.slice(2));
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

  vendorRuntime(resolveRuntimeSrc(args.runtimeSrc));

  const ids = args.only ?? Object.keys(manifest.grammars);
  for (const id of ids) {
    const spec = manifest.grammars[id];
    if (!spec) fail(`unknown grammar '${id}' (not in grammar-versions.json)`);
    vendorGrammar(id, spec);
  }

  regenerateDefaultRegistry(manifest);
  console.log('[vendor-grammars] done. Commit packages/core/cpp/highlight/vendor/.');
}

main();
