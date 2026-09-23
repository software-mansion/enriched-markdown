#!/usr/bin/env node
/**
 * Generates the general-purpose benchmark documents.
 *
 * Only features every library renders out of the box are used — plain CommonMark,
 * because that is all Markwon's core supports without plugins:
 *
 *   headings (ATX + setext), paragraphs, emphasis / strong, code spans,
 *   fenced + indented code blocks, block quotes, bullet + ordered lists (nested),
 *   thematic breaks, inline + reference links, hard line breaks.
 *
 * Deliberately absent: tables, strikethrough, autolinks, task lists, images, HTML.
 *
 * Output (deterministic, fixed-seed PRNG):
 *   simple_{small,medium,large}.md   headings + plain paragraphs
 *   complex_{small,medium,large}.md  every shared feature, mixed
 *   feature_showcase.md              each construct once, for visual parity checks
 *
 * Simple and complex documents share the same byte targets, so a difference in
 * cost comes from the markup rather than from the amount of text.
 *
 * Run: node display-benchmark/tools/generate-documents.mjs
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = join(ROOT, 'fixtures');

const SIZES = {
  small: 2_000,
  medium: 20_000,
  large: 100_000,
};

/** Deterministic PRNG (numerical recipes LCG) so documents never drift between runs. */
function makeRandom(seed) {
  let state = seed >>> 0;
  return () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 0x100000000;
  };
}

const WORDS = [
  'render', 'layout', 'measure', 'frame', 'buffer', 'thread', 'screen', 'scroll',
  'document', 'parser', 'node', 'tree', 'span', 'glyph', 'cache', 'value',
  'window', 'surface', 'content', 'element', 'block', 'inline', 'style', 'theme',
  'device', 'memory', 'budget', 'latency', 'result', 'sample', 'metric', 'trace',
  'simple', 'quick', 'steady', 'large', 'small', 'stable', 'visible', 'hidden',
  'always', 'rarely', 'often', 'during', 'before', 'after', 'while', 'across',
  'the', 'a', 'of', 'to', 'and', 'in', 'on', 'with', 'for', 'from', 'by', 'every',
];

// Identifier-safe words only, for code.
const IDENTS = [
  'frame', 'buffer', 'layout', 'node', 'span', 'cache', 'value', 'width',
  'height', 'offset', 'count', 'index', 'state', 'result', 'item', 'size',
];

const pick = (rnd, arr) => arr[Math.floor(rnd() * arr.length) % arr.length];
const between = (rnd, min, max) => min + Math.floor(rnd() * (max - min + 1));
const capitalize = (s) => s.charAt(0).toUpperCase() + s.slice(1);

function words(rnd, n) {
  return Array.from({ length: n }, () => pick(rnd, WORDS));
}

/** A plain sentence: no markup at all. */
function plainSentence(rnd) {
  return capitalize(words(rnd, between(rnd, 8, 18)).join(' ')) + '.';
}

function plainParagraph(rnd, sentences = between(rnd, 3, 6)) {
  return Array.from({ length: sentences }, () => plainSentence(rnd)).join(' ');
}

/**
 * A sentence dense with inline markup. Markup always wraps whole words separated
 * by spaces, and the sentence ends on a plain word, so no construct depends on
 * the flanking-delimiter edge cases where parsers are known to disagree.
 */
function richSentence(rnd, refs) {
  const n = between(rnd, 10, 18);
  const out = [];
  for (let i = 0; i < n; i++) {
    const w = pick(rnd, WORDS);
    const last = i === n - 1;
    const roll = last ? 1 : rnd();
    if (roll < 0.08) out.push(`**${w}**`);
    else if (roll < 0.16) out.push(`*${w}*`);
    else if (roll < 0.20) out.push(`***${w}***`);
    else if (roll < 0.27) out.push(`\`${pick(rnd, IDENTS)}()\``);
    else if (roll < 0.31) out.push(`[${w} ${pick(rnd, WORDS)}](https://example.com/${pick(rnd, IDENTS)} "${capitalize(w)}")`);
    else if (roll < 0.34) {
      const id = refs.next++;
      refs.defs.push(`[ref-${id}]: https://example.com/ref/${id} "Reference ${id}"`);
      out.push(`[${w}][ref-${id}]`);
    } else out.push(w);
  }
  return capitalize(out.join(' ')) + '.';
}

function richParagraph(rnd, refs, sentences = between(rnd, 2, 4)) {
  return Array.from({ length: sentences }, () => richSentence(rnd, refs)).join(' ');
}

/** Short lines only (< 40 chars): libraries differ on wrapping vs scrolling long code. */
function codeLines(rnd) {
  const fn = pick(rnd, IDENTS);
  const a = pick(rnd, IDENTS);
  const b = pick(rnd, IDENTS);
  const lines = [`fun ${fn}Of(${a}: Int): Int {`];
  for (let i = 0, n = between(rnd, 3, 8); i < n; i++) {
    const v = `${pick(rnd, IDENTS)}${i}`;
    lines.push(rnd() < 0.5 ? `    val ${v} = ${a} * ${i + 2}` : `    if (${a} > ${i}) return ${a}`);
  }
  lines.push(`    return ${b}(${a})`, '}');
  return lines;
}

function fencedCode(rnd) {
  return ['```kotlin', ...codeLines(rnd), '```'].join('\n');
}

/** Must follow a paragraph, never a list: after a list the indent would continue the list. */
function indentedCode(rnd) {
  return codeLines(rnd).map((l) => `    ${l}`).join('\n');
}

function bulletList(rnd) {
  const lines = [];
  for (let i = 0, n = between(rnd, 3, 5); i < n; i++) {
    lines.push(`- ${capitalize(words(rnd, between(rnd, 3, 9)).join(' '))}`);
    if (rnd() < 0.6) {
      for (let j = 0, m = between(rnd, 1, 3); j < m; j++) {
        lines.push(`  - ${capitalize(words(rnd, between(rnd, 3, 7)).join(' '))}`);
        if (rnd() < 0.4) lines.push(`    - ${capitalize(words(rnd, between(rnd, 2, 6)).join(' '))}`);
      }
    }
  }
  return lines.join('\n');
}

function orderedList(rnd) {
  const lines = [];
  for (let i = 0, n = between(rnd, 3, 6); i < n; i++) {
    lines.push(`${i + 1}. ${capitalize(words(rnd, between(rnd, 4, 10)).join(' '))}`);
    if (rnd() < 0.3) lines.push(`   - ${capitalize(words(rnd, between(rnd, 3, 7)).join(' '))}`);
  }
  return lines.join('\n');
}

function blockQuote(rnd, refs) {
  const lines = [`> ${richSentence(rnd, refs)}`, '>', `> ${plainParagraph(rnd, 2)}`];
  if (rnd() < 0.4) lines.push('>', `> > ${plainSentence(rnd)}`);
  return lines.join('\n');
}

/** Two trailing spaces: the hard-break form every parser here recognises. */
function paragraphWithHardBreaks(rnd) {
  return [plainSentence(rnd), plainSentence(rnd), plainSentence(rnd)].join('  \n');
}

function simpleSection(rnd, index) {
  const parts = [`## ${capitalize(words(rnd, between(rnd, 2, 5)).join(' '))} ${index}`, ''];
  for (let i = 0, n = between(rnd, 2, 4); i < n; i++) parts.push(plainParagraph(rnd), '');
  return parts.join('\n');
}

function complexSection(rnd, index) {
  const refs = { next: index * 100, defs: [] };
  const title = capitalize(words(rnd, between(rnd, 2, 5)).join(' '));
  const parts = [];

  // Alternate heading syntaxes so both parser paths are exercised.
  if (index % 3 === 0) parts.push(`${title} ${index}`, '-'.repeat(title.length + 4), '');
  else parts.push(`## ${title} ${index}`, '');

  parts.push(richParagraph(rnd, refs), '');
  parts.push(bulletList(rnd), '');
  parts.push(richParagraph(rnd, refs), '');
  parts.push(fencedCode(rnd), '');
  parts.push(`### ${capitalize(words(rnd, between(rnd, 2, 4)).join(' '))}`, '');
  parts.push(blockQuote(rnd, refs), '');
  parts.push(orderedList(rnd), '');
  parts.push(richParagraph(rnd, refs, 2), '');
  if (index % 2 === 0) parts.push(indentedCode(rnd), '');
  if (index % 4 === 1) parts.push(`#### ${capitalize(words(rnd, 3).join(' '))}`, '', paragraphWithHardBreaks(rnd), '');
  parts.push('---', '');
  if (refs.defs.length) parts.push(...refs.defs, '');
  return parts.join('\n');
}

/** Appends whole sections until the document reaches the byte target. */
function grow(title, intro, targetBytes, seed, section) {
  const rnd = makeRandom(seed);
  let doc = `# ${title}\n\n${intro}\n\n`;
  for (let i = 1; Buffer.byteLength(doc) < targetBytes; i++) doc += section(rnd, i);
  return doc;
}

// Spelled out: literal trailing spaces are easily stripped by editors.
const HARD_BREAK = '  ';

const SHOWCASE = `# Feature showcase

Every construct used by the benchmark documents, once each. Use this document to
check that all libraries render the same elements before comparing any numbers.

Setext heading level 1
======================

Setext heading level 2
----------------------

## ATX heading level 2

### ATX heading level 3

#### ATX heading level 4

##### ATX heading level 5

###### ATX heading level 6

A paragraph with **strong**, *emphasis*, ***strong emphasis***, a \`codeSpan()\`,
an [inline link](https://example.com "Example title") and a [reference link][ref].
A backslash-escaped \\*asterisk\\* stays literal.

A paragraph with hard line breaks,${HARD_BREAK}
made with two trailing spaces,${HARD_BREAK}
on every line.

> A block quote with **inline** markup.
>
> A second paragraph in the same quote.
>
> > A nested block quote.

- Bullet item
- Bullet item with children
  - Nested bullet
    - Doubly nested bullet
- Last bullet item

1. Ordered item
2. Ordered item with a child
   - Nested bullet inside an ordered list
3. Last ordered item

\`\`\`kotlin
fun widthOf(value: Int): Int {
    val size = value * 2
    return size
}
\`\`\`

An indented code block follows this paragraph.

    fun heightOf(value: Int): Int {
        return value + 1
    }

---

[ref]: https://example.com/reference "Reference title"
`;

const DOCUMENTS = {
  'feature_showcase.md': SHOWCASE,
};

for (const [size, bytes] of Object.entries(SIZES)) {
  DOCUMENTS[`simple_${size}.md`] = grow(
    `Simple document (${size})`,
    'Headings and plain paragraphs only, with no inline markup.',
    bytes,
    0xD0C0_1000 + bytes,
    simpleSection,
  );
  DOCUMENTS[`complex_${size}.md`] = grow(
    `Complex document (${size})`,
    'Every CommonMark feature shared by all libraries, mixed.',
    bytes,
    0xD0C0_2000 + bytes,
    complexSection,
  );
}

mkdirSync(OUT, { recursive: true });
for (const [name, content] of Object.entries(DOCUMENTS)) {
  writeFileSync(join(OUT, name), content, 'utf8');
  const lines = content.split('\n').length;
  console.log(`${name.padEnd(22)} ${String(Buffer.byteLength(content)).padStart(8)} bytes  ${String(lines).padStart(6)} lines`);
}
console.log(`\nWrote ${Object.keys(DOCUMENTS).length} documents to ${OUT}`);
