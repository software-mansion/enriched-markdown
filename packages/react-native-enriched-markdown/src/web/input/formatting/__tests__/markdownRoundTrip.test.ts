import { parseToPlainTextAndRanges } from '../InputParser';
import { FormattingStore } from '../FormattingStore';
import { BlockStore } from '../BlockStore';
import { serialize } from '../MarkdownSerializer';
import { createBlockRange } from '../../model/blocks';
import { createFormattingRange } from '../../model/inlineStyles';

async function roundTrip(markdown: string): Promise<string> {
  const { plainText, formattingRanges, blockRanges } =
    await parseToPlainTextAndRanges(markdown);

  const styles = new FormattingStore();
  styles.setRanges(formattingRanges);
  const blocks = new BlockStore();
  blocks.setRanges(blockRanges);

  return serialize(plainText, styles.allRanges, blocks.allRanges);
}

// Canonical documents: already in the serializer's output form, so the
// round trip must reproduce them byte for byte.
const CANONICAL_FIXTURES = [
  '',
  'rebase the **feature** branch onto *main*',
  'checkout _detached_, drop ~~WIP~~, hide ||the token||',
  'read the [docs](https://git-scm.com) first',
  'bare https://git-scm.com stays plain text',
  '# Setup',
  '## Rebase\n\n1. fetch\n2. merge',
  '### Deploy **now**',
  '***hotfix***',
  '**_hotfix_**',
  '- stack\n  - review',
  '- a\n  - b\n    - c',
  '- stack\n  - review\n  1. merge',
  // A nested item is indented to its parent's rendered marker width, so an
  // ordered parent ("1. ") indents a column further than a bullet ("- "),
  // and a mixed chain accumulates the two widths.
  '1. fetch\n   - nested',
  '1. fetch\n   1. nested',
  '- a\n  1. b\n     - c',
  // An empty item keeps its marker wherever md4c reads it back as one.
  '- a\n- \n- c',
  '1. a\n2. \n3. c',
  '- \n- b',
  '- a\n- ',
  '- a\n  - b\n- \n- d',
  '- a\n  - b\n  - \n  - d',
  '- \n  - b',
  'a\n\n- \n- b',
  '1. fetch\n2. merge\n\nrebase\n\n1. push',
  'git fetch\n\n\n\ngit merge',
  // latexMath is off for the input dialect, so dollar delimiters are text.
  '$$x^2$$',
  // Plain text that would read as markup is escaped on the way out.
  '\\*not em\\*',
  '\\# not a heading',
  '2 \\*\\* 2',
  'a \\|\\| b',
  '# Use \\#',
  '- \\- x',
  '**bold \\* star**',
  '[a\\]b](https://x.dev)',
];

// Non-canonical input: one pass normalizes it into the expected form.
const NORMALIZATION_FIXTURES: Array<[before: string, after: string]> = [
  ['**force push', '**force push**'],
  ['~~drop ||squash', '~~drop ||squash||~~'],
  ['[changelog](https://git-scm', '[changelog](https://git-scm)'],
  // Styles covering exactly the link text move inside the link.
  ['**[docs](https://x.dev)**', '[**docs**](https://x.dev)'],
  // An empty heading is an editing-time anchor; import drops it (as native).
  ['# ', ''],
  // Headings are separated by a blank line on the way out.
  ['# h1\n## h2', '# h1\n\n## h2'],
  // Nesting indent is re-derived from the parent's marker width, so a wider
  // hand-typed indent still nests and collapses to the canonical column.
  ['- stack\n   - review', '- stack\n  - review'],
  ['- a\n   - b\n      - c', '- a\n  - b\n    - c'],
  ['- stack\n   - review\n   1. merge', '- stack\n  - review\n  1. merge'],
  // Ordered markers come from the block store's renumbering, not the source.
  ['9. a\n   - b', '1. a\n   - b'],
];

// Blocks md4c reports (TOP_LEVEL_BLOCK_TYPES in InputParser) that the input
// model has no BlockType for. Their markers are dropped and the content
// survives as plain paragraphs. Pinned so the loss stays a decision: a future
// BlockType for any of these turns into a diff here.
const UNSUPPORTED_BLOCK_FIXTURES: Array<[before: string, after: string]> = [
  ['> quote', 'quote'],
  ['> quote\n> more', 'quote\nmore'],
  ['| a | b |\n| - | - |\n| 1 | 2 |', 'ab12'],
  ['---', ''],
  ['a\n\n---\n\nb', 'a\n\n\n\nb'],
  ['`inline code`', 'inline code'],
];

// Inputs that need a second pass to settle: a fenced code block's content
// carries the trailing newline md4c reports, which the next pass absorbs.
const TWO_PASS_FIXTURES: Array<
  [source: string, firstPass: string, settled: string]
> = [
  ['```\ncode\n```', 'code\n', 'code'],
  ['```js\nconst a = 1;\n```', 'const a = 1;\n', 'const a = 1;'],
];

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

  it.each(TWO_PASS_FIXTURES)(
    'settles %j only on the second pass',
    async (source, firstPass, settled) => {
      const once = await roundTrip(source);
      expect(once).toBe(firstPass);
      const twice = await roundTrip(once);
      expect(twice).toBe(settled);
      expect(await roundTrip(twice)).toBe(settled);
    }
  );

  it.each([
    ...CANONICAL_FIXTURES,
    ...ONE_PASS_FIXTURES.map(([, after]) => after),
  ])('is idempotent for the settled form %j', async (markdown) => {
    expect(await roundTrip(markdown)).toBe(markdown);
  });
});

// Text the user typed, which carries no markup of its own, has to come back
// as the same text with the same styles. Each case is serialized from the
// model, not written as markdown, the way the editor saves it.
const PLAIN_TEXT_CASES: string[] = [
  '5 * 2 = 10',
  'x = a_b',
  'snake_case is fine',
  'array[0',
  'a]b',
  'true || false',
  'use ` here',
  '&copy; 2024',
  'Tom &amp; Jerry',
  'AT&T and R&D',
  '1984. A novel',
  '3) third',
  'a\n===',
  'a\n---',
  '- item typed as text',
  '+ plus',
  '# not a heading',
  '###### six',
  '> not a quote',
  '~~ approx',
  '~single~',
  'back\\slash',
  'line ends with \\',
  '<div>hello</div>',
  'a <b>c</b>',
  '<https://x.dev>',
  '![alt](img.png)',
  '[x](y)',
  '**not bold**',
  '_under_',
  '***',
  '___',
  '```',
  '~~~',
  '1. a\n2. b',
  '#hashtag',
  'ends with #',
  'C# and F#',
  '=',
];

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
  it('keeps an indented dash as text, losing the indent', async () => {
    expect(await modelOf(serialize('  - indented dash', [], []))).toEqual({
      text: '- indented dash',
      ranges: [],
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
