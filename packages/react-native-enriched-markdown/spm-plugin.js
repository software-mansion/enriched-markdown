// React Native SwiftPM autolinking plugin (`npx react-native spm`). Registered through
// "swiftpmConfig".autolinkingPlugin in package.json, which React Native reads from 0.88
// on. React Native marks this plugin contract as preview, so it may change between RN
// versions.
//
// It runs on every `npx react-native spm` and on every "Sync SPM Autolinking" Xcode
// pre-action, and does three things:
//
// 1. Bakes the app package.json "enriched-markdown" block into Package.swift. Xcode
//    caches evaluated manifests and only re-evaluates one whose content changed, so a
//    manifest that read package.json itself would keep building with a stale config.
//    Writing the block into the manifest makes a config change a manifest change.
//    The manifest also checks which vendored assets (RaTeX, grammars) are on disk, so
//    a fingerprint of them is baked too: assets that arrive after the first build, or
//    a package upgrade, then change the manifest as well.
// 2. Watches the app package.json and the asset directories, so editing the block or
//    fetching the assets re-runs the sync. As with `pod install`, run
//    `npx react-native spm` after either; otherwise the change lands one build later
//    (Xcode resolves packages before the pre-action).
// 3. Adds our package to the app. Declaring a plugin makes React Native skip its own
//    wiring for this library, including the libs/<name> symlink our default relative
//    paths assume, so the React Native package paths are baked in as well.
'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const LOG = '[react-native-enriched-markdown]';
const BEGIN = '// BEGIN enriched-markdown baked config';
const END = '// END enriched-markdown baked config';
const PACKAGE_NAME = 'ReactNativeEnrichedMarkdown';

// Swift raw string literal with enough # around it that the value can't end it early.
const swiftString = (value) => {
  const runs = value.match(/["\\]#*/g) ?? [];
  const hashes = '#'.repeat(
    Math.max(0, ...runs.map((run) => run.length - 1)) + 1
  );
  return `${hashes}"${value}"${hashes}`;
};

function readConfig(appPackageJson) {
  let json;
  try {
    json = JSON.parse(fs.readFileSync(appPackageJson, 'utf8'));
  } catch {
    return {};
  }
  const block = json['enriched-markdown'];
  return block && typeof block === 'object' && !Array.isArray(block)
    ? block
    : {};
}

const isFile = (relativePath) => {
  try {
    return fs.statSync(path.join(__dirname, relativePath)).isFile();
  } catch {
    return false;
  }
};

function warnAboutMissingAssets(config) {
  const fix =
    'If this is unintended, run `node node_modules/react-native-enriched-markdown/postinstall.mjs`, ' +
    'then `npx react-native spm`.';
  const ratexPresent =
    fs.existsSync(path.join(__dirname, 'ios/vendor/RaTeX.xcframework')) &&
    isFile('ios/vendor/.stamp');
  if (config.enableMath !== false && !ratexPresent) {
    console.warn(
      `${LOG} LaTeX math disabled: the vendored RaTeX assets were not found at ios/vendor. ${fix}`
    );
  }
  const grammarsPresent =
    isFile('cpp/highlight/vendor/grammars/.stamp') &&
    isFile('cpp/highlight/vendor/guarded/generated_registry.cpp');
  if (config.enableCodeHighlight !== false && !grammarsPresent) {
    console.warn(
      `${LOG} code highlighting disabled: the tree-sitter grammars were not found at cpp/highlight/vendor. ${fix}`
    );
  }
}

function assetsFingerprint() {
  const read = (relativePath) => {
    try {
      return fs.readFileSync(path.join(__dirname, relativePath), 'utf8');
    } catch {
      return '';
    }
  };
  return crypto
    .createHash('sha256')
    .update(
      [
        'package.json',
        'ios/vendor/.stamp',
        'cpp/highlight/vendor/grammars/.stamp',
      ]
        .map(read)
        .join('\0')
    )
    .digest('hex')
    .slice(0, 16);
}

function bakedBlock(config, reactNativePackagePath, generatedCodePackagePath) {
  const json = JSON.stringify(config, Object.keys(config).sort());
  return (
    `${BEGIN}\n` +
    `// Vendored assets: ${assetsFingerprint()}\n` +
    `let bakedConfigJSON: String? = ${swiftString(json)}\n` +
    `let reactNativePackagePath = ${swiftString(reactNativePackagePath)}\n` +
    `let generatedCodePackagePath = ${swiftString(generatedCodePackagePath)}\n`
  );
}

function bakeManifest(manifestPath, block) {
  const manifest = fs.readFileSync(manifestPath, 'utf8');
  const start = manifest.indexOf(BEGIN);
  const end = manifest.indexOf(END);
  if (start === -1 || end === -1 || end < start) {
    throw new Error(
      `${LOG} ${manifestPath} is missing its baked-config markers; reinstall the package.`
    );
  }
  const next = manifest.slice(0, start) + block + manifest.slice(end);
  if (next !== manifest) fs.writeFileSync(manifestPath, next);
}

function enrichedMarkdownSpmPlugin(context) {
  const appPackageJson = path.join(context.projectRoot, 'package.json');

  const reactNativePackagePath = context.react?.packageRef?.path;
  if (!reactNativePackagePath) {
    throw new Error(
      `${LOG} SwiftPM: only a local React Native package (prebuilt xcframeworks) is supported.`
    );
  }
  const generatedCodePackagePath = path.join(context.outputDir, '..', 'ios');

  const config = readConfig(appPackageJson);
  warnAboutMissingAssets(config);
  bakeManifest(
    path.join(__dirname, 'Package.swift'),
    bakedBlock(config, reactNativePackagePath, generatedCodePackagePath)
  );

  return {
    packageDependencies: [{ name: PACKAGE_NAME, path: __dirname }],
    productDependencies: [{ name: PACKAGE_NAME, package: PACKAGE_NAME }],
    watchPaths: [
      appPackageJson,
      path.join(__dirname, 'ios'),
      path.join(__dirname, 'cpp/highlight/vendor'),
      path.join(__dirname, 'cpp/highlight/vendor/grammars/.stamp'),
    ],
  };
}

module.exports = enrichedMarkdownSpmPlugin;
