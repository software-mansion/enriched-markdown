import { loadParser } from '../../../parseMarkdown';
import { parseToPlainTextAndRanges } from '../InputParser';
import { FormattingStore } from '../FormattingStore';
import { BlockStore } from '../BlockStore';
import { serialize } from '../MarkdownSerializer';
import { createBlockRange, type BlockType } from '../../model/blocks';
import {
  createFormattingRange,
  type InputStyleType,
} from '../../model/inlineStyles';
import {
  canonical,
  knownLimitations,
  normalization,
  plainText,
  unsupported,
  type ModelCase,
} from './inputFixtures';

// Import and export run in the WASM core, which loads asynchronously.
beforeAll(() => loadParser());

async function roundTrip(markdown: string): Promise<string> {
  const { plainText, formattingRanges, blockRanges } =
    await parseToPlainTextAndRanges(markdown);

  const styles = new FormattingStore();
  styles.setRanges(formattingRanges);
  const blocks = new BlockStore();
  blocks.setRanges(blockRanges);

  return serialize(plainText, styles.allRanges, blocks.allRanges);
}

const CANONICAL_FIXTURES = canonical();
const NORMALIZATION_FIXTURES = normalization();
const UNSUPPORTED_BLOCK_FIXTURES = unsupported();
const ONE_PASS_FIXTURES = [
  ...NORMALIZATION_FIXTURES,
  ...UNSUPPORTED_BLOCK_FIXTURES,
];

describe('markdown round trip', () => {
  it.each(CANONICAL_FIXTURES)(
    'reproduces %j byte for byte',
    async (markdown) => {
      expect(await roundTrip(markdown)).toBe(markdown);
    }
  );

  it.each(NORMALIZATION_FIXTURES)(
    'normalizes %j to %j in one pass',
    async (before, after) => {
      expect(await roundTrip(before)).toBe(after);
    }
  );

  it.each(UNSUPPORTED_BLOCK_FIXTURES)(
    'flattens the unsupported block %j to %j',
    async (before, after) => {
      expect(await roundTrip(before)).toBe(after);
    }
  );

  it.each([
    ...CANONICAL_FIXTURES,
    ...ONE_PASS_FIXTURES.map(([, after]) => after),
  ])('is idempotent for the settled form %j', async (markdown) => {
    expect(await roundTrip(markdown)).toBe(markdown);
  });

  // Any markdown reaches a fixed point after one round trip and keeps its text.
  it.each([
    ...CANONICAL_FIXTURES,
    ...ONE_PASS_FIXTURES.flatMap(([before, after]) => [before, after]),
  ])('settles %j after one pass without losing text', async (markdown) => {
    const once = await roundTrip(markdown);

    expect(await roundTrip(once)).toBe(once);
    expect((await parseToPlainTextAndRanges(once)).plainText).toBe(
      (await parseToPlainTextAndRanges(markdown)).plainText
    );
  });
});

// Behavior of the reference that looks wrong and is pinned on purpose, so that
// changing it is a decision (cpp/tests/fixtures/input/known-limitations.json).
describe('known limitations', () => {
  const limitations = knownLimitations();
  const chains = limitations.flatMap((entry) =>
    entry.kind === 'chain' ? [entry] : []
  );
  const models = limitations.flatMap((entry) =>
    entry.kind === 'model' ? [entry] : []
  );

  it.each(chains.map((entry) => [entry.description, entry] as const))(
    'chain: %s',
    async (_, entry) => {
      let markdown = entry.markdown;
      for (const expected of entry.trips) {
        markdown = await roundTrip(markdown);
        expect(markdown).toBe(expected);
      }
      expect(await roundTrip(markdown)).toBe(markdown);
    }
  );

  const BLOCK_TYPES: Record<string, BlockType> = {
    p: 'paragraph',
    h1: 'h1',
    h2: 'h2',
    h3: 'h3',
    h4: 'h4',
    h5: 'h5',
    h6: 'h6',
    ul: 'unordered-list-item',
    ol: 'ordered-list-item',
  };

  it.each(models.map((entry) => [entry.description, entry] as const))(
    'model: %s',
    async (_, entry: ModelCase) => {
      const markdown = serialize(
        entry.text,
        entry.ranges.map(([type, start, end, url]) =>
          createFormattingRange(type as InputStyleType, start, end, url)
        ),
        entry.blocks.map(([type, start, end, level]) =>
          createBlockRange(BLOCK_TYPES[type]!, start, end, level)
        )
      );
      expect(markdown).toBe(entry.markdown);

      const parsed = await parseToPlainTextAndRanges(markdown);
      expect(parsed.plainText).toBe(entry.parsedText);
      if (entry.parsedLinks !== undefined) {
        expect(parsed.formattingRanges.map((range) => range.url)).toEqual(
          entry.parsedLinks
        );
      }
      if (entry.parsedBlocks !== undefined) {
        expect(parsed.blockRanges).toHaveLength(entry.parsedBlocks);
      }
    }
  );
});

// Text the user typed, which carries no markup of its own, has to come back
// as the same text with the same styles. Each case is serialized from the
// model, not written as markdown, the way the editor saves it.
const PLAIN_TEXT_CASES = plainText();

async function modelOf(markdown: string) {
  const { plainText, formattingRanges, blockRanges } =
    await parseToPlainTextAndRanges(markdown);
  const styles = new FormattingStore();
  styles.setRanges(formattingRanges);
  const blocks = new BlockStore();
  blocks.setRanges(blockRanges);
  return {
    text: plainText,
    ranges: styles.allRanges.map(({ type, start, end }) => ({
      type,
      start,
      end,
    })),
    blocks: blocks.allRanges.map(({ type, start, end }) => ({
      type,
      start,
      end,
    })),
  };
}

describe('plain text escaping', () => {
  // Known limitation: md4c strips a line's leading whitespace and markdown
  // has no escape for it (an entity would do, but the parser drops entities,
  // review §2.5.5). The marker after it still stays text.
  it('keeps an indented dash as text, with its indent', async () => {
    expect(await modelOf(serialize('  - indented dash', [], []))).toEqual({
      text: '  - indented dash',
      ranges: [],
      blocks: [],
    });
  });

  // Leading whitespace goes out as typed and import keeps it as text, as on
  // iOS, rather than dropping it or reading an indented code block.
  it.each([
    '\tfoo',
    '  foo',
    '    foo',
    '\t\tfoo\nbar',
    'a\n\tb',
    'a\n\n    b',
  ])('keeps the leading whitespace of %j', async (text) => {
    const markdown = serialize(text, [], []);

    expect(markdown).toBe(text);
    expect(await modelOf(markdown)).toEqual({ text, ranges: [], blocks: [] });
  });

  it('keeps an indented marker the user typed as text, at any depth', async () => {
    const text = '    - x\n\t# y\n      1. z';
    const markdown = serialize(text, [], []);

    expect(markdown).toBe('    \\- x\n\t\\# y\n      1\\. z');
    expect(await modelOf(markdown)).toEqual({ text, ranges: [], blocks: [] });
  });

  it('keeps the whitespace after a list or heading marker as text', async () => {
    const blocks = [
      createBlockRange('unordered-list-item', 0, 5, 0),
      createBlockRange('h1', 6, 10, 1),
    ];

    const markdown = serialize('  foo\n\tbar', [], blocks);

    expect(markdown).toBe('-   foo\n# \tbar');
    expect(await modelOf(markdown)).toEqual({
      text: '  foo\n\tbar',
      ranges: [],
      blocks: [
        { type: 'unordered-list-item', start: 0, end: 5 },
        { type: 'h1', start: 6, end: 10 },
      ],
    });
  });

  it('keeps structural indentation as structure', async () => {
    // A nested item's indent and an indented bullet are list syntax, not text.
    expect(await modelOf('- a\n  - b\n   - c')).toEqual({
      text: 'a\nb\nc',
      ranges: [],
      blocks: [
        { type: 'unordered-list-item', start: 0, end: 1 },
        { type: 'unordered-list-item', start: 2, end: 3 },
        { type: 'unordered-list-item', start: 4, end: 5 },
      ],
    });
    // A line of only whitespace is still a blank line.
    expect((await modelOf('a\n   \nb')).text).toBe('a\n\nb');
    // Formatting after the whitespace keeps its offsets.
    expect(await modelOf('  **bold**')).toEqual({
      text: '  bold',
      ranges: [{ type: 'strong', start: 2, end: 6 }],
      blocks: [],
    });
  });

  it.each(PLAIN_TEXT_CASES)('keeps %j as plain text', async (text) => {
    const markdown = serialize(text, [], []);

    expect(await modelOf(markdown)).toEqual({ text, ranges: [], blocks: [] });
  });

  it.each(PLAIN_TEXT_CASES)(
    'keeps %j as plain text inside a heading, a list item and bold',
    async (text) => {
      if (text.includes('\n')) {
        return;
      }
      for (const block of ['h2', 'unordered-list-item'] as const) {
        const blocks = [
          {
            ...createBlockRange(block, 0, text.length),
            level: block === 'h2' ? 2 : 0,
          },
        ];
        const ranges = [createFormattingRange('strong', 0, text.length)];
        const markdown = serialize(text, ranges, blocks);
        const model = await modelOf(markdown);

        expect([markdown, model.text]).toEqual([markdown, text]);
        expect(model.blocks.map((b) => b.type)).toEqual([block]);
      }
    }
  );
});
