#!/usr/bin/env node
// Writes the `headerSearchPaths` list in the React Native package's Package.swift.
//
// SwiftPM has no headermap, so every directory under ios/ and common/ that holds a
// header must be listed for bare-name imports (`#import "Foo.h"`) to resolve. The
// cpp/ directories the target compiles are fixed roots.
//
//   node scripts/generate-spm-header-paths.mjs           Rewrite the list.
//   node scripts/generate-spm-header-paths.mjs --check   Exit 1 if it is out of date,
//     or if the baked-config block holds an app's values: spm-plugin.js writes them
//     into this tracked file when an app links the package from this checkout.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  '../packages/react-native-enriched-markdown'
);
const PACKAGE_SWIFT = path.join(ROOT, 'Package.swift');
const SCANNED = ['common', 'ios'];
const SKIPPED = /^ios\/(include|vendor[^/]*|build|generated)$/;
const FIXED = [
  'cpp/enrmrkd',
  'cpp/parser',
  'cpp/repair',
  'cpp/highlight',
  'cpp/latex',
];
const LIST = /(let headerSearchPaths: \[String\] = \[\n)([\s\S]*?)(\n\])/;

function headerDirs(dir) {
  if (SKIPPED.test(dir)) return [];
  const entries = fs.readdirSync(path.join(ROOT, dir), { withFileTypes: true });
  const hasHeader = entries.some(
    (e) => e.isFile() && (e.name.endsWith('.h') || e.name.endsWith('.hpp'))
  );
  return [
    ...(hasHeader ? [dir] : []),
    ...entries
      .filter((e) => e.isDirectory())
      .flatMap((e) => headerDirs(`${dir}/${e.name}`)),
  ];
}

const expected = [...SCANNED.flatMap(headerDirs).sort(), ...FIXED];
const manifest = fs.readFileSync(PACKAGE_SWIFT, 'utf8');
if (!LIST.test(manifest)) {
  console.error(
    '`let headerSearchPaths: [String] = [` not found in Package.swift'
  );
  process.exit(1);
}
const list = expected.map((d) => `    "${d}",`).join('\n');
const generated = manifest.replace(
  LIST,
  (_, open, __, close) => open + list + close
);

if (!process.argv.includes('--check')) {
  fs.writeFileSync(PACKAGE_SWIFT, generated);
} else {
  const problems = [];
  if (generated !== manifest) {
    problems.push(
      'headerSearchPaths is out of date; run `yarn generate-spm-header-paths`.'
    );
  }
  if (!/let bakedConfigJSON: String\? = nil\n/.test(manifest)) {
    problems.push(
      'the baked-config block holds an app’s values; reset it to the defaults before committing.'
    );
  }
  if (problems.length > 0) {
    console.error(problems.map((p) => `Package.swift: ${p}`).join('\n'));
    process.exit(1);
  }
}
