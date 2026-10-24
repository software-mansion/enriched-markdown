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
  // A single newline between blocks is no blank line and a blank line is one
  // empty line, wherever the blocks are - including between list items.
  '# h1\n## h2',
  '# Head\nbody',
  '# Head\n\nbody',
  'para\n- item',
  'para\n# h',
  '- a\n\n- b',
  '- a\n\n\n- b\n\nc\n\n\nd',
  '- a\n\nb',
  '1. a\n\n1. b',
  'rebase the **feature** branch onto *main*',
  'checkout _detached_, drop ~~WIP~~, hide ||the token||',
  'read the [docs](https://git-scm.com) first',
  // Bold and italic meeting inside a word: one "*" run between letters.
  '***a***bcd',
  '**a*b***cd',
  'a***bc***d',
  // "!" against a link's "[" would read as an image.
  'Wow\\![docs](https://git-scm.com)',
  'Wow! [docs](https://git-scm.com)',
  '**Wow!**[docs](https://git-scm.com)',
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
  // The model cannot hold an empty line above a nested item without
  // de-nesting it, so that blank line is the one dropped.
  ['- a\n  - b\n\n  - c', '- a\n  - b\n  - c'],
  ['- a\n\n  - b', '- a\n  - b'],
  // An unclosed delimiter is literal text: it comes back escaped, never
  // closed, and never with characters the caller did not pass.
  ['**force push', '\\*\\*force push'],
  ['~~drop ||squash', '\\~\\~drop \\|\\|squash'],
  ['[changelog](https://git-scm', '\\[changelog\\](https://git-scm'],
  ['use snake_case here', 'use snake\\_case here'],
  ['2*3 = 6', '2\\*3 = 6'],
  ['a||b', 'a\\|\\|b'],
  ['see [docs', 'see \\[docs'],
  // Styles covering exactly the link text move inside the link.
  ['**[docs](https://x.dev)**', '[**docs**](https://x.dev)'],
  // An empty heading is an editing-time anchor; import drops it (as native).
  ['# ', ''],
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
  // A code block keeps its lines and ends like any other block.
  ['```\ncode\n```', 'code'],
  ['```js\nconst a = 1;\n```', 'const a = 1;'],
  ['```\ncode\n```\nafter', 'code\nafter'],
  ['~~~\nt\n~~~', 't'],
  ['a\n\n```\nx\ny\n```\n\nb', 'a\n\nx\ny\n\nb'],
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
