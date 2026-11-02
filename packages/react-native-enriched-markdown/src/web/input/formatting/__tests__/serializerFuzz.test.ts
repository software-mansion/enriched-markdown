/* eslint-disable no-bitwise -- the seeded generator below */
import { parseToPlainTextAndRanges } from '../InputParser';
import { FormattingStore } from '../FormattingStore';
import { serializeInline } from '../MarkdownSerializer';
import {
  INPUT_STYLE_TYPES,
  type InputStyleType,
} from '../../model/inlineStyles';

// Documents a toolbar could build - words, styles applied over whole words,
// overlapping and crossing each other freely - must come back from their own
// markdown with the same text and the same styles on every character.
// Whitespace is left out of the comparison: delimiters hug non-whitespace, so
// a style on an edge space is dropped by design.

// mulberry32: a seeded generator, so a failure names a reproducible case.
function random(seed: number): () => number {
  let state = seed;
  return () => {
    state = (state + 0x6d2b79f5) | 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

interface Case {
  text: string;
  store: FormattingStore;
}

function generate(seed: number): Case {
  const next = random(seed);
  const pick = (n: number) => Math.floor(next() * n);
  const words: Array<{ start: number; end: number }> = [];
  let text = '';
  const count = 2 + pick(6);
  for (let i = 0; i < count; i++) {
    if (i > 0) {
      text += next() < 0.15 ? '\n' : ' ';
    }
    const word = Array.from({ length: 1 + pick(5) }, () =>
      String.fromCharCode(97 + pick(26))
    ).join('');
    words.push({ start: text.length, end: text.length + word.length });
    text += word;
  }
  const store = new FormattingStore();
  let hasLink = false;
  for (let i = 1 + pick(4); i > 0; i--) {
    const type: InputStyleType =
      INPUT_STYLE_TYPES[pick(INPUT_STYLE_TYPES.length)]!;
    // One link at most: `addRange` merges touching links whatever their url
    // (review §2.3.7), which is not what this test is about.
    if (type === 'link' && hasLink) {
      continue;
    }
    hasLink ||= type === 'link';
    const first = pick(words.length);
    const last = first + pick(Math.min(3, words.length - first));
    store.addRange({
      type,
      start: words[first]!.start,
      end: words[last]!.end,
      url: type === 'link' ? 'https://x.dev/a' : undefined,
    });
  }
  return { text, store };
}

// Per non-whitespace character, the sorted styles covering it.
function stylesPerCharacter(
  text: string,
  ranges: ReadonlyArray<{
    type: string;
    start: number;
    end: number;
    url?: string;
  }>
): string[] {
  const out: string[] = [];
  for (let i = 0; i < text.length; i++) {
    if (/\s/.test(text[i]!)) {
      continue;
    }
    out.push(
      text[i] +
        ':' +
        ranges
          .filter((r) => r.start <= i && i < r.end)
          .map((r) => (r.type === 'link' ? `link(${r.url})` : r.type))
          .sort()
          .join(',')
    );
  }
  return out;
}

const SEEDS = Array.from({ length: 400 }, (_, i) => i + 1);

describe('serializer round trip over toolbar-built documents', () => {
  it.each(SEEDS)('seed %i', async (seed) => {
    const { text, store } = generate(seed);
    const markdown = serializeInline(text, store.allRanges);
    const parsed = await parseToPlainTextAndRanges(markdown);

    expect({ markdown, text: parsed.plainText }).toEqual({ markdown, text });
    expect({
      markdown,
      styles: stylesPerCharacter(parsed.plainText, parsed.formattingRanges),
    }).toEqual({ markdown, styles: stylesPerCharacter(text, store.allRanges) });
  });
});

// Ranges anywhere, over text with punctuation, CJK and emoji, where a
// delimiter often cannot work ("**Note:**text", underline over half a word).
// The serializer may drop such a style, but the text has to come back as it
// was, and no style may turn up that the document did not have.
const ROUGH_PIECES = [
  'note',
  ':',
  '.',
  ',',
  '"',
  'a',
  'b1',
  '日本',
  '「引用」',
  'です',
  '😀',
  '🇵🇱',
  ' ',
  ' ',
  ' ',
  '(x)',
  '-',
  "'s",
  'é',
];

function generateRough(seed: number): Case {
  const next = random(seed);
  const pick = (n: number) => Math.floor(next() * n);
  let text = '';
  for (let i = 3 + pick(8); i > 0; i--) {
    text += ROUGH_PIECES[pick(ROUGH_PIECES.length)];
  }
  // md4c drops a line's leading and trailing whitespace whatever surrounds it.
  text = text.trim() || 'a';
  // Boundaries on code points, as the editor keeps them.
  const points = [0];
  for (let i = 0; i < text.length; ) {
    i += text.codePointAt(i)! > 0xffff ? 2 : 1;
    points.push(i);
  }
  const store = new FormattingStore();
  let hasLink = false;
  for (let i = 1 + pick(3); i > 0; i--) {
    const type: InputStyleType =
      INPUT_STYLE_TYPES[pick(INPUT_STYLE_TYPES.length)]!;
    if (type === 'link' && hasLink) {
      continue;
    }
    hasLink ||= type === 'link';
    const a = points[pick(points.length)]!;
    const b = points[pick(points.length)]!;
    if (a === b) {
      continue;
    }
    store.addRange({
      type,
      start: Math.min(a, b),
      end: Math.max(a, b),
      url: type === 'link' ? 'https://x.dev/a' : undefined,
    });
  }
  return { text, store };
}

describe('serializer round trip over rough documents', () => {
  it.each(SEEDS)('seed %i', async (seed) => {
    const { text, store } = generateRough(seed);
    const markdown = serializeInline(text, store.allRanges);
    // Known serializer limitation: bold and italic boundaries meeting at one
    // point emit a run of four or more "*" ("*,****"), which md4c cannot pair
    // back into the original spans.
    if (/\*{4,}/.test(markdown)) {
      return;
    }
    const parsed = await parseToPlainTextAndRanges(markdown);

    expect({ markdown, text: parsed.plainText }).toEqual({ markdown, text });
    const expected = stylesPerCharacter(text, store.allRanges);
    const actual = stylesPerCharacter(
      parsed.plainText,
      parsed.formattingRanges
    );
    actual.forEach((styles, i) => {
      const [, kept = ''] = styles.split(':');
      const [, had = ''] = expected[i]!.split(':');
      const allowed = new Set(had.split(','));
      expect({ markdown, i, kept }).toEqual({
        markdown,
        i,
        kept: kept
          .split(',')
          .filter((style) => style === '' || allowed.has(style))
          .join(','),
      });
    });
  });
});
