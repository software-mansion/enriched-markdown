#!/usr/bin/env node
// Generates cpp/repair/UnicodeTables.hpp: sorted inclusive code point ranges
// for Unicode General Categories L (letters) and N (numbers), as classified by
// the JS engine running this script. The repair module's word-character test
// mirrors the reference implementation's /[\p{L}\p{N}_]/u, so the table is
// produced from V8's own classification rather than a separately downloaded
// Unicode data file. Rerun only to pick up a newer Unicode version; the
// generated header is committed and records the versions it came from.
//
// Usage: yarn workspace @enriched-markdown/core unicode-tables
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, '..', 'cpp', 'repair', 'UnicodeTables.hpp');

const letterOrNumber = /[\p{L}\p{N}]/u;
const ranges = [];
let start = -1;
for (let cp = 0; cp <= 0x10ffff; cp++) {
  if (cp >= 0xd800 && cp <= 0xdfff) {
    if (start !== -1) {
      ranges.push([start, cp - 1]);
      start = -1;
    }
    continue;
  }
  const hit = letterOrNumber.test(String.fromCodePoint(cp));
  if (hit && start === -1) {
    start = cp;
  } else if (!hit && start !== -1) {
    ranges.push([start, cp - 1]);
    start = -1;
  }
}
if (start !== -1) ranges.push([start, 0x10ffff]);

const hex = (n) => '0x' + n.toString(16).toUpperCase().padStart(4, '0');
const lines = [];
lines.push('// GENERATED FILE - DO NOT EDIT.');
lines.push('// Produced by packages/core/scripts/generate-unicode-tables.mjs');
lines.push(`// Node ${process.versions.node}, V8 ${process.versions.v8}, Unicode ${process.versions.unicode}`);
lines.push('//');
lines.push('// Inclusive code point ranges matching /[\\p{L}\\p{N}]/u.');
lines.push('#pragma once');
lines.push('');
lines.push('#include <cstddef>');
lines.push('#include <cstdint>');
lines.push('');
lines.push('namespace Markdown::UnicodeTables {');
lines.push('');
lines.push('struct Range {');
lines.push('  uint32_t first;');
lines.push('  uint32_t last;');
lines.push('};');
lines.push('');
lines.push(`inline constexpr size_t kLetterOrNumberRangeCount = ${ranges.length};`);
lines.push('inline constexpr Range kLetterOrNumberRanges[kLetterOrNumberRangeCount] = {');
for (let i = 0; i < ranges.length; i += 4) {
  const chunk = ranges.slice(i, i + 4).map(([a, b]) => `{${hex(a)}, ${hex(b)}}`);
  lines.push('    ' + chunk.join(', ') + ',');
}
lines.push('};');
lines.push('');
lines.push('} // namespace Markdown::UnicodeTables');
lines.push('');
writeFileSync(out, lines.join('\n'));
console.log(`wrote ${out}: ${ranges.length} ranges (Unicode ${process.versions.unicode})`);
