#!/usr/bin/env node
// Restores RaTeX's prebuilt static XCFramework, its four core Swift sources, and
// the KaTeX fonts into packages/react-native-enriched-markdown/ios/vendor/.
//
// This replaces React Native's `spm_dependency` wiring for iOS math. spm_dependency
// checks out RaTeX from SPM and builds/signs its Swift wrapper at app-build time,
// which produced arch-specific swiftmodules (#527) and duplicate signed-XCFramework
// signatures that collide during archive assembly (#491). Vendoring the already-built,
// already-signed XCFramework once removes that whole class of SPM/CocoaPods interop
// bugs and drops the requirement to `use_frameworks! :linkage => :dynamic`.
//
// The vendor tree is GITIGNORED and reproduced on demand from the pins in
// ratex-version.json, mirroring the tree-sitter runtime restore in vendor-grammars.mjs.
// Wired into the package `prepare` hook (self-heal the working tree) and `prepack`
// (bake the full set into the published npm tarball). Idempotent: a `.stamp`
// fingerprint on the pinned tag + both asset sha256s makes repeat runs a no-op.
//
//   node vendor/vendor-ratex.mjs            Ensure the vendored set is present/current.
//   node vendor/vendor-ratex.mjs --force    Re-fetch and rewrite regardless of the stamp.
//
// Offline: point a manifest url at a local file path (absolute) and it is read from
// disk instead of fetched; the sha256 is still verified.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..');
let manifestPath = path.join(here, 'ratex-version.json');
let outDir = path.join(repoRoot, 'packages/react-native-enriched-markdown/ios/vendor');

const LOG_PREFIX = '[react-native-enriched-markdown]';
const log = (m) => console.log(`${LOG_PREFIX} ${m}`);
const fail = (m) => { console.error(`${LOG_PREFIX} ${m}`); process.exit(1); };

function parseArgs(argv) {
  const args = { force: false, manifest: null, output: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--force') args.force = true;
    else if (argv[i] === '--manifest') args.manifest = argv[++i];
    else if (argv[i] === '--output') args.output = argv[++i];
  }
  return args;
}

function copyFile(src, dest) {
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(src, dest);
}

// Reads a manifest asset from a local path when the url points at an existing file
// (offline), otherwise fetches it. The sha256 is verified either way; a mismatch is
// fatal and prints the computed digest to paste back into ratex-version.json on a re-pin.
async function fetchAndVerify(url, sha256, label) {
  if (!sha256) fail(`${label}.sha256 missing in ratex-version.json; cannot verify ${url}`);
  let buf;
  if (path.isAbsolute(url) && fs.existsSync(url)) {
    log(`reading ${label} from local ${url}`);
    buf = fs.readFileSync(url);
  } else {
    log(`fetching ${label} from ${url}`);
    try {
      const res = await fetch(url);
      if (!res.ok) fail(`${label} download failed: ${res.status} ${res.statusText} for ${url}`);
      buf = Buffer.from(await res.arrayBuffer());
    } catch (err) {
      fail(`${label} download failed for ${url}: ${err.message}`);
    }
  }
  const digest = crypto.createHash('sha256').update(buf).digest('hex');
  if (digest !== sha256) {
    fail(
      `${label} sha256 mismatch for ${url}\n  expected ${sha256}\n  got      ${digest}\n` +
        'If this is a deliberate re-pin, update the sha256 in vendor/ratex-version.json to the "got" value.'
    );
  }
  return buf;
}

function extractTo(buf, ext, args, tmp) {
  const archive = path.join(tmp, `ratex${ext}`);
  fs.writeFileSync(archive, buf);
  const tool = ext === '.zip' ? 'unzip' : 'tar';
  const argv = ext === '.zip' ? ['-q', '-o', archive, ...args] : ['-xzf', archive, ...args];
  const res = spawnSync(tool, argv, { stdio: 'inherit' });
  if (res.status !== 0) fail(`${tool} failed to extract ${archive} (status ${res.status})`);
}

function stampKey(m) {
  return `${m.tag}|${m.xcframework.sha256}|${m.source.sha256}`;
}

function present(m, dir) {
  if (!fs.existsSync(path.join(dir, 'RaTeX.xcframework/Info.plist'))) return false;
  for (const rel of m.source.swiftSources) {
    if (!fs.existsSync(path.join(dir, path.basename(rel)))) return false;
  }
  return fs.existsSync(path.join(dir, 'Fonts'));
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.manifest) manifestPath = path.resolve(args.manifest);
  if (args.output) outDir = path.resolve(args.output);

  const xcframeworkDir = path.join(outDir, 'RaTeX.xcframework');
  const fontsOut = path.join(outDir, 'Fonts');
  const stampFile = path.join(outDir, '.stamp');

  const m = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  const key = stampKey(m);

  if (!args.force && present(m, outDir) &&
      (fs.existsSync(stampFile) ? fs.readFileSync(stampFile, 'utf8').trim() : null) === key) {
    log('RaTeX vendor tree already up to date; skipping.');
    return;
  }

  fs.rmSync(outDir, { recursive: true, force: true });
  fs.mkdirSync(outDir, { recursive: true });

  // 1. Prebuilt static XCFramework (device + simulator[arm64,x86_64] + macOS slices).
  const xcBuf = await fetchAndVerify(m.xcframework.url, m.xcframework.sha256, 'xcframework');
  {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'ratex-xcf-'));
    try {
      extractTo(xcBuf, '.zip', ['-d', outDir], tmp);
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
    if (!fs.existsSync(xcframeworkDir)) fail(`extracted zip has no RaTeX.xcframework in ${outDir}`);
  }

  // 2. Core Swift sources + KaTeX fonts + LICENSE from the pinned source tag.
  const srcBuf = await fetchAndVerify(m.source.url, m.source.sha256, 'source');
  {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'ratex-src-'));
    try {
      extractTo(srcBuf, '.tgz', ['-C', tmp], tmp);
      const root = path.join(tmp, m.source.prefix);
      if (!fs.existsSync(root)) fail(`source tarball has no ${m.source.prefix}/ directory`);

      for (const rel of m.source.swiftSources) {
        const from = path.join(root, rel);
        if (!fs.existsSync(from)) fail(`source tarball missing ${rel}`);
        copyFile(from, path.join(outDir, path.basename(rel)));
      }

      const fontsSrc = path.join(root, m.source.fontsDir);
      if (!fs.existsSync(fontsSrc)) fail(`source tarball missing ${m.source.fontsDir}`);
      let n = 0;
      for (const f of fs.readdirSync(fontsSrc)) {
        if (f.endsWith('.ttf')) { copyFile(path.join(fontsSrc, f), path.join(fontsOut, f)); n++; }
      }
      if (n === 0) fail(`no .ttf fonts found under ${m.source.fontsDir}`);

      const licenseFrom = path.join(root, m.source.license);
      if (fs.existsSync(licenseFrom)) copyFile(licenseFrom, path.join(outDir, 'LICENSE'));
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  }

  fs.writeFileSync(stampFile, key + '\n');
  log(`RaTeX ${m.tag} -> ${outDir}`);
  log('done.');
}

main().catch((err) => fail(err && err.stack ? err.stack : String(err)));
