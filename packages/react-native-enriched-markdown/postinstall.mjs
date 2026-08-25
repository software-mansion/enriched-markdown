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
// missing feature. In a monorepo INIT_CWD is the workspace root where the install
// ran, so the download opt-out lives in the root package.json (one shared node_modules).
//
// The native build reads the *app* package.json directly (via the podspec's
// installation root / gradle's build root -- see the podspecs and android/build.gradle),
// which is a separate per-app decision. It reconciles that flag with asset presence on
// disk: an explicit opt-in with the asset missing fails loud, a default-on with it
// missing degrades to a clean build.
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

// This script only decides what to DOWNLOAD into node_modules. The native build
// (podspec + build.gradle) reads the app package.json directly to decide what to
// compile/link, so nothing is written here for it to consume. The `codeHighlightLanguages`
// subset is a build-time concern (a language subset is selected from the full downloaded
// grammar set), so it is intentionally not read here. ENV vars are a deprecated fallback,
// honored only when package.json has no explicit value.
let enableCodeHighlight = consumerConfig.enableCodeHighlight;
let enableMath = consumerConfig.enableMath;

if (enableCodeHighlight === undefined && process.env.ENRICHED_MARKDOWN_ENABLE_CODE_HIGHLIGHT) {
  console.warn(`${LOG} DEPRECATED: ENRICHED_MARKDOWN_ENABLE_CODE_HIGHLIGHT env var will be removed in a future version. Configure via "enriched-markdown".enableCodeHighlight in your package.json instead.`);
  enableCodeHighlight = process.env.ENRICHED_MARKDOWN_ENABLE_CODE_HIGHLIGHT !== '0';
}
if (enableMath === undefined && process.env.ENRICHED_MARKDOWN_ENABLE_MATH) {
  console.warn(`${LOG} DEPRECATED: ENRICHED_MARKDOWN_ENABLE_MATH env var will be removed in a future version. Configure via "enriched-markdown".enableMath in your package.json instead.`);
  enableMath = process.env.ENRICHED_MARKDOWN_ENABLE_MATH !== '0';
}

enableCodeHighlight = enableCodeHighlight !== false;
enableMath = enableMath !== false;

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
