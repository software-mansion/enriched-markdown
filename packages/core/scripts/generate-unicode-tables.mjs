#!/usr/bin/env node
// Generates cpp/repair/UnicodeTables.hpp: sorted inclusive code point ranges
// for Unicode General Categories L and N (letters and numbers) and P and S
// (punctuation and symbols), as classified by the JS engine running this
// script. The repair module's word-character test mirrors the reference
// implementation's /[\p{L}\p{N}_]/u and its punctuation test md4c's, so the
// tables are produced from V8's own classification rather than a separately
// downloaded Unicode data file. Rerun only to pick up a newer Unicode
// version; the generated header is committed and records the versions it
// came from.
//
// Usage: yarn workspace @enriched-markdown/core unicode-tables
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, '..', 'cpp', 'repair', 'UnicodeTables.hpp');

const tables = [
  {
    name: 'LetterOrNumber',
    pattern: /[\p{L}\p{N}]/u,
    source: '/[\\p{L}\\p{N}]/u',
  },
  {
    name: 'Punctuation',
    pattern: /[\p{P}\p{S}]/u,
    source: '/[\\p{P}\\p{S}]/u',
  },
];

function rangesOf(pattern) {
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
    const hit = pattern.test(String.fromCodePoint(cp));
    if (hit && start === -1) {
      start = cp;
    } else if (!hit && start !== -1) {
      ranges.push([start, cp - 1]);
      start = -1;
    }
  }
  if (start !== -1) ranges.push([start, 0x10ffff]);
  return ranges;
}

const hex = (n) => '0x' + n.toString(16).toUpperCase().padStart(4, '0');
const lines = [];
lines.push('// GENERATED FILE - DO NOT EDIT.');
lines.push('// Produced by packages/core/scripts/generate-unicode-tables.mjs');
lines.push(
  `// Node ${process.versions.node}, V8 ${process.versions.v8}, Unicode ${process.versions.unicode}`
);
lines.push('//');
lines.push(
  '// Inclusive code point ranges matching the regex named above each table.'
);
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
const summary = [];
for (const { name, pattern, source } of tables) {
  const ranges = rangesOf(pattern);
  lines.push('');
  lines.push(`// ${source}`);
  lines.push(`inline constexpr size_t k${name}RangeCount = ${ranges.length};`);
  lines.push('// clang-format off');
  lines.push(`inline constexpr Range k${name}Ranges[k${name}RangeCount] = {`);
  for (let i = 0; i < ranges.length; i += 4) {
    const chunk = ranges
      .slice(i, i + 4)
      .map(([a, b]) => `{${hex(a)}, ${hex(b)}}`);
    lines.push('    ' + chunk.join(', ') + ',');
  }
  lines.push('};');
  lines.push('// clang-format on');
  summary.push(`${ranges.length} ${name} ranges`);
}
lines.push('');
lines.push('} // namespace Markdown::UnicodeTables');
lines.push('');
writeFileSync(out, lines.join('\n'));
console.log(
  `wrote ${out}: ${summary.join(', ')} (Unicode ${process.versions.unicode})`
);
