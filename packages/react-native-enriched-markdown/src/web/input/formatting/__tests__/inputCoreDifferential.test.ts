/* eslint-disable no-bitwise -- the seeded generator below */
import fs from 'node:fs';
import path from 'node:path';
import { loadParser } from '../../../parseMarkdown';
import { parseToPlainTextAndRanges } from '../InputParser';
import { serialize } from '../MarkdownSerializer';
import { parseWithCore, serializeWithCore } from '../inputCore';
import { BlockStore } from '../BlockStore';
import { FormattingStore } from '../FormattingStore';
import {
  createBlockRange,
  HEADING_BLOCK_TYPES,
  type BlockRange,
} from '../../model/blocks';
import {
  INPUT_STYLE_TYPES,
  type FormattingRange,
} from '../../model/inlineStyles';

// The TypeScript implementation is the reference the C++ core was ported from.
// This runs both over the shared fixtures and a seeded corpus and asserts the
// same result, so the web can switch to the core without changing an output
// byte. Lone surrogates are left out on purpose: the TypeScript path turns
// each into three replacement characters and shifts the ranges after them, the
// core into one. Removed with the TypeScript implementation.

const FIXTURES = path.resolve(
  __dirname,
  '../../../../../../core/cpp/tests/fixtures/input'
);

interface Model {
  text: string;
  formatting: FormattingRange[];
  blocks: BlockRange[];
}

function stringsIn(value: unknown, into: Set<string>): void {
  if (typeof value === 'string') {
    into.add(value);
  } else if (Array.isArray(value)) {
    value.forEach((item) => stringsIn(item, into));
  } else if (value !== null && typeof value === 'object') {
    for (const [key, item] of Object.entries(value)) {
      if (key !== 'description') {
        stringsIn(item, into);
      }
    }
  }
}

function fixtureMarkdown(): { documents: string[]; models: Model[] } {
  const documents = new Set<string>();
  const models: Model[] = [];
  for (const file of fs.readdirSync(FIXTURES)) {
    const json = JSON.parse(fs.readFileSync(path.join(FIXTURES, file), 'utf8'));
    for (const entry of json.cases) {
      if (
        entry !== null &&
        typeof entry === 'object' &&
        !Array.isArray(entry)
      ) {
        // known-limitations: chains and editor models.
        if (entry.kind === 'model') {
          models.push({
            text: entry.text,
            formatting: entry.ranges.map(
              ([type, start, end, url]: [string, number, number, string?]) => ({
                type,
                start,
                end,
                ...(url === undefined ? {} : { url }),
              })
            ),
            blocks: entry.blocks.map(
              ([type, start, end, level]: [string, number, number, number]) =>
                createBlockRange(
                  type === 'ul'
                    ? 'unordered-list-item'
                    : type === 'ol'
                      ? 'ordered-list-item'
                      : type === 'paragraph'
                        ? 'paragraph'
                        : (HEADING_BLOCK_TYPES[Number(type.slice(1)) - 1] ??
                          'paragraph'),
                  start,
                  end,
                  level
                )
            ),
          });
        }
      }
      stringsIn(entry, documents);
    }
  }
  return { documents: [...documents], models };
}

// mulberry32, as in serializerFuzz.test.ts.
function random(seed: number): () => number {
  let state = seed;
  return () => {
    state = (state + 0x6d2b79f5) | 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const MARKUP = [
  '*',
  '_',
  '~',
  '|',
  '[',
  ']',
  '#',
  '-',
  '+',
  '>',
  '1.',
  '2)',
  '\\',
  '&',
  '`',
  '<',
  '!',
  '=',
  '(',
  ')',
  '**',
  '__',
  '~~',
  '||',
  '](',
  '&amp;',
  '10.',
  '---',
  '```',
  '$',
  '^',
  ':',
  '- ',
  '# ',
  '## ',
  '1. ',
  '> ',
  '  ',
  '    ',
  '\t',
];
const WORDS = ['a', 'bc', 'xyz', 'foo', '7', 'snake_case', 'x1', 'Note', 'ok'];
// Non-ASCII punctuation, symbols, CJK, emoji and unusual whitespace: what the
// flanking checks classify with Unicode classes.
const UNICODE = [
  '“',
  '”',
  '‘',
  '’',
  '—',
  '–',
  '…',
  '、',
  '。',
  '「',
  '」',
  '・',
  '¡',
  '¿',
  '«',
  '»',
  '€',
  '£',
  '©',
  '™',
  '≠',
  '√',
  '日本',
  '語',
  'です',
  'é',
  'ß',
  'İ',
  'Ω',
  'ж',
  '😀',
  '👍🏽',
  '🇵🇱',
  '👨‍👩‍👧',
  ' ',
  ' ',
  '　',
  '​',
  ' ',
  '﻿',
  '́',
  '‮',
  '',
  '',
];
const URLS = [
  'https://x.dev/a',
  'https://x.dev/a b',
  'a(b',
  'a)b',
  'a\\',
  'x<y>z',
  'u',
  '日本',
  'https://x.dev/(a)',
  '',
];

function generateMarkdown(seed: number): string {
  const next = random(seed);
  const pick = (n: number) => Math.floor(next() * n);
  const piece = () => {
    const roll = next();
    if (roll < 0.35) {
      return MARKUP[pick(MARKUP.length)]!;
    }
    if (roll < 0.6) {
      return WORDS[pick(WORDS.length)]!;
    }
    if (roll < 0.85) {
      return UNICODE[pick(UNICODE.length)]!;
    }
    if (roll < 0.92) {
      return ` [${WORDS[pick(WORDS.length)]}](${URLS[pick(URLS.length)]}) `;
    }
    return ' ';
  };
  const lines: string[] = [];
  for (let line = 1 + pick(5); line > 0; line--) {
    let text = '';
    const prefix = pick(8);
    if (prefix === 1) {
      text = `${'#'.repeat(1 + pick(6))} `;
    } else if (prefix === 2) {
      text = `${'  '.repeat(pick(4))}- `;
    } else if (prefix === 3) {
      text = `${'   '.repeat(pick(3))}${1 + pick(12)}. `;
    }
    for (let count = pick(8); count > 0; count--) {
      text += piece();
    }
    lines.push(text);
    if (next() < 0.2) {
      lines.push('');
    }
  }
  return lines.join(next() < 0.05 ? '\r\n' : '\n');
}

function codePointBoundaries(text: string): number[] {
  const points = [0];
  for (let i = 0; i < text.length; ) {
    i += text.codePointAt(i)! > 0xffff ? 2 : 1;
    points.push(i);
  }
  return points;
}

// A model as the editor holds it: ranges added through the stores, so they
// arrive normalized, on code point boundaries, one block per line.
function generateModel(seed: number): Model {
  const next = random(seed);
  const pick = (n: number) => Math.floor(next() * n);
  const lines: string[] = [];
  for (let line = 1 + pick(5); line > 0; line--) {
    let text = '';
    for (let count = pick(6); count > 0; count--) {
      const roll = next();
      text +=
        roll < 0.4
          ? MARKUP[pick(MARKUP.length)]!
          : roll < 0.65
            ? WORDS[pick(WORDS.length)]!
            : roll < 0.9
              ? UNICODE[pick(UNICODE.length)]!
              : ' ';
    }
    lines.push(text);
  }
  const text = lines.join('\n');
  const points = codePointBoundaries(text);
  const formattingStore = new FormattingStore();
  let hasLink = false;
  for (let i = pick(5); i > 0; i--) {
    const type = INPUT_STYLE_TYPES[pick(INPUT_STYLE_TYPES.length)]!;
    if (type === 'link' && hasLink) {
      continue;
    }
    hasLink ||= type === 'link';
    const a = points[pick(points.length)]!;
    const b = points[pick(points.length)]!;
    if (a === b) {
      continue;
    }
    formattingStore.addRange({
      type,
      start: Math.min(a, b),
      end: Math.max(a, b),
      url: type === 'link' ? URLS[pick(URLS.length)]! : undefined,
    });
  }

  const blocks: BlockRange[] = [];
  let offset = 0;
  for (const line of lines) {
    const start = offset;
    const end = offset + line.length;
    offset = end + 1;
    const roll = pick(7);
    if (roll === 1) {
      blocks.push(
        createBlockRange(HEADING_BLOCK_TYPES[pick(6)]!, start, end, 0)
      );
    } else if (roll === 2 || roll === 3) {
      blocks.push(createBlockRange('unordered-list-item', start, end, pick(4)));
    } else if (roll === 4 || roll === 5) {
      blocks.push(createBlockRange('ordered-list-item', start, end, pick(4)));
    }
  }
  for (const block of blocks) {
    const heading = HEADING_BLOCK_TYPES.indexOf(block.type as never);
    if (heading >= 0) {
      block.level = heading + 1;
    }
  }
  const blockStore = new BlockStore();
  blockStore.setRanges(blocks);
  return {
    text,
    formatting: [...formattingStore.allRanges],
    blocks: [...blockStore.allRanges],
  };
}

function inEditorForm(parsed: {
  formattingRanges: FormattingRange[];
  blockRanges: BlockRange[];
}) {
  const formattingStore = new FormattingStore();
  formattingStore.setRanges(parsed.formattingRanges);
  const blockStore = new BlockStore();
  blockStore.setRanges(parsed.blockRanges);
  return {
    formatting: [...formattingStore.allRanges],
    blocks: [...blockStore.allRanges],
  };
}

const MARKDOWN_SEEDS = 20000;
const MODEL_SEEDS = 10000;

const mismatches = (found: unknown[]) => found.slice(0, 5);

describe('the wasm input core against the TypeScript implementation', () => {
  const fixtures = fixtureMarkdown();
  const documents = [
    ...fixtures.documents,
    ...Array.from({ length: MARKDOWN_SEEDS }, (_, i) =>
      generateMarkdown(i + 1)
    ),
  ];

  beforeAll(async () => {
    await loadParser();
  });

  it('has a corpus worth the name', () => {
    expect(fixtures.documents.length).toBeGreaterThan(100);
    expect(documents.length).toBeGreaterThan(20000);
  });

  it('parses every document to the same text and ranges', async () => {
    const found: unknown[] = [];
    const seen = { styles: 0, blocks: 0, links: 0, nonAscii: 0 };
    for (const markdown of documents) {
      const reference = await parseToPlainTextAndRanges(markdown);
      const actual = parseWithCore(markdown);
      seen.styles += actual.formattingRanges.length;
      seen.blocks += actual.blockRanges.length;
      seen.links += actual.formattingRanges.filter(
        (range) => range.type === 'link'
      ).length;
      // eslint-disable-next-line no-control-regex -- counting non-ASCII text
      seen.nonAscii += /[^\x00-\x7f]/.test(actual.plainText) ? 1 : 0;
      const referenceStores = inEditorForm(reference);
      // The core settles list metadata itself, as the block store does.
      const matches =
        reference.plainText === actual.plainText &&
        JSON.stringify(reference.formattingRanges) ===
          JSON.stringify(actual.formattingRanges) &&
        JSON.stringify(referenceStores.blocks) ===
          JSON.stringify(actual.blockRanges) &&
        JSON.stringify(inEditorForm(actual).blocks) ===
          JSON.stringify(actual.blockRanges);
      if (!matches) {
        found.push({ markdown, reference, referenceStores, actual });
      }
    }
    expect(mismatches(found)).toEqual([]);
    expect(found.length).toBe(0);
    // The corpus must exercise what it claims to.
    expect(seen.styles).toBeGreaterThan(5000);
    expect(seen.blocks).toBeGreaterThan(5000);
    expect(seen.links).toBeGreaterThan(1000);
    expect(seen.nonAscii).toBeGreaterThan(5000);
  });

  it('serializes every parsed document to the same markdown', async () => {
    const found: unknown[] = [];
    for (const markdown of documents) {
      const parsed = await parseToPlainTextAndRanges(markdown);
      const { formatting, blocks } = inEditorForm(parsed);
      const reference = serialize(parsed.plainText, formatting, blocks);
      const actual = serializeWithCore(parsed.plainText, formatting, blocks);
      if (reference !== actual) {
        found.push({ markdown, reference, actual });
      }
    }
    expect(mismatches(found)).toEqual([]);
    expect(found.length).toBe(0);
  });

  it('serializes editor models to the same markdown', () => {
    const models = [
      ...fixtures.models,
      ...Array.from({ length: MODEL_SEEDS }, (_, i) => generateModel(i + 1)),
    ];
    const found: unknown[] = [];
    for (const model of models) {
      const reference = serialize(model.text, model.formatting, model.blocks);
      const actual = serializeWithCore(
        model.text,
        model.formatting,
        model.blocks
      );
      if (reference !== actual) {
        found.push({ model, reference, actual });
      }
    }
    expect(mismatches(found)).toEqual([]);
    expect(found.length).toBe(0);
  });

  it('round trips every model to the same text and ranges', async () => {
    const found: unknown[] = [];
    for (let seed = 1; seed <= MODEL_SEEDS; seed++) {
      const model = generateModel(seed);
      const markdown = serialize(model.text, model.formatting, model.blocks);
      const reference = await parseToPlainTextAndRanges(markdown);
      const actual = parseWithCore(
        serializeWithCore(model.text, model.formatting, model.blocks)
      );
      const matches =
        reference.plainText === actual.plainText &&
        JSON.stringify(reference.formattingRanges) ===
          JSON.stringify(actual.formattingRanges) &&
        JSON.stringify(inEditorForm(reference).blocks) ===
          JSON.stringify(actual.blockRanges);
      if (!matches) {
        found.push({ model, markdown, reference, actual });
      }
    }
    expect(mismatches(found)).toEqual([]);
    expect(found.length).toBe(0);
  });
});
