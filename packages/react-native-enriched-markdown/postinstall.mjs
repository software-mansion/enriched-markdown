#!/usr/bin/env node
// Thin wrapper that invokes vendor-grammars.mjs and vendor-ratex.mjs in
// consumer mode (--from-npm) to download vendored native assets after install.
//
// In the monorepo, grammar-versions.json is not present at the expected path
// (it is only copied during prepack), so this script is a no-op -- the
// `prepare` script handles vendoring via the same scripts with monorepo paths.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const PKG_ROOT = path.dirname(fileURLToPath(import.meta.url));
const LOG = '[react-native-enriched-markdown]';

const grammarManifest = path.join(PKG_ROOT, 'cpp/highlight/grammar-versions.json');
if (!fs.existsSync(grammarManifest)) {
  console.log(`${LOG} grammar-versions.json not found; skipping postinstall.`);
  console.log(`${LOG} This is expected in monorepo development (use \`yarn prepare\`).`);
  process.exit(0);
}

// Consumer opt-out. npm/yarn/pnpm set INIT_CWD to the project root running the
// install, so the consumer declares which heavy native assets to skip downloading
// via an `enriched-markdown` block in their own package.json:
//
//   { "enriched-markdown": { "enableCodeHighlight": false, "enableMath": false } }
//
// Both features default to enabled (opt-out, not opt-in). Any resolution failure
// (INIT_CWD unset, unreadable/malformed JSON, absent key) falls back to downloading
// everything -- a skipped download is far cheaper to recover from than a silently
// missing feature. The native build mirrors this by keying off asset presence on
// disk (see the podspecs and android/build.gradle), so a package.json opt-out alone
// yields a clean build with no Podfile/gradle edits.
function resolveConsumerConfig() {
  const initCwd = process.env.INIT_CWD;
  if (!initCwd) {
    return {};
  }
  try {
    const pkg = JSON.parse(fs.readFileSync(path.join(initCwd, 'package.json'), 'utf8'));
    const config = pkg['enriched-markdown'];
    return config && typeof config === 'object' ? config : {};
  } catch {
    return {};
  }
}

const consumerConfig = resolveConsumerConfig();
const enableCodeHighlight = consumerConfig.enableCodeHighlight !== false;
const enableMath = consumerConfig.enableMath !== false;

if (!enableCodeHighlight && !enableMath) {
  console.log(`${LOG} both code highlighting and math are disabled via package.json ("enriched-markdown"); skipping postinstall.`);
  process.exit(0);
}

console.log(`${LOG} restoring vendored native assets ...`);

const vendorGrammars = path.join(PKG_ROOT, 'vendor-grammars.mjs');
const vendorRatex = path.join(PKG_ROOT, 'vendor-ratex.mjs');
const vendorDir = path.join(PKG_ROOT, 'cpp/highlight/vendor');
const ratexManifest = path.join(PKG_ROOT, 'ratex-version.json');
const iosVendor = path.join(PKG_ROOT, 'ios/vendor');

let failed = false;

// Tree-sitter runtime + grammar C sources
if (enableCodeHighlight) {
  const r1 = spawnSync(process.execPath, [
    vendorGrammars,
    '--from-npm',
    '--vendor-dir', vendorDir,
    '--manifest', grammarManifest,
  ], { stdio: 'inherit' });
  if (r1.status !== 0) {
    console.warn(`${LOG} WARNING: vendor-grammars failed. Code highlighting may not work.`);
    failed = true;
  }
} else {
  console.log(`${LOG} code highlighting disabled via package.json ("enriched-markdown".enableCodeHighlight = false); skipping tree-sitter grammars.`);
}

// RaTeX XCFramework + Swift sources + fonts (iOS math)
if (!enableMath) {
  console.log(`${LOG} math disabled via package.json ("enriched-markdown".enableMath = false); skipping RaTeX.`);
} else if (fs.existsSync(ratexManifest) && fs.existsSync(vendorRatex)) {
  const r2 = spawnSync(process.execPath, [
    vendorRatex,
    '--manifest', ratexManifest,
    '--output', iosVendor,
  ], { stdio: 'inherit' });
  if (r2.status !== 0) {
    console.warn(`${LOG} WARNING: vendor-ratex failed. iOS math rendering may not work.`);
    failed = true;
  }
}

if (failed) {
  console.warn(
    `${LOG} Some downloads failed. Ensure network access to registry.npmjs.org and github.com, ` +
    `then re-run: node node_modules/react-native-enriched-markdown/postinstall.mjs`
  );
}

console.log(`${LOG} postinstall complete.`);
