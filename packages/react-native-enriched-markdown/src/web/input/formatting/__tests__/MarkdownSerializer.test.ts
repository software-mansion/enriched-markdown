import {
  markdownLinePrefix,
  serialize,
  serializeInline,
  ZWSP,
} from '../MarkdownSerializer';
import { createBlockRange } from '../../model/blocks';
import { createFormattingRange as range } from '../../model/inlineStyles';

describe('serializeInline', () => {
  it('wraps each style in its dialect delimiters', () => {
    const text = 'The world is big';

    expect(serializeInline(text, [range('strong', 4, 9)])).toBe(
      'The **world** is big'
    );
    expect(serializeInline(text, [range('em', 4, 9)])).toBe(
      'The *world* is big'
    );
    expect(serializeInline(text, [range('underline', 4, 9)])).toBe(
      'The _world_ is big'
    );
    expect(serializeInline(text, [range('strikethrough', 4, 9)])).toBe(
      'The ~~world~~ is big'
    );
    expect(serializeInline(text, [range('spoiler', 4, 9)])).toBe(
      'The ||world|| is big'
    );
    expect(
      serializeInline(text, [range('link', 4, 9, 'https://a.example')])
    ).toBe('The [world](https://a.example) is big');
  });

  it('nests overlapping styles by priority, font styles outermost', () => {
    const text = 'The world is big';

    expect(
      serializeInline(text, [range('spoiler', 4, 9), range('em', 4, 9)])
    ).toBe('The *||world||* is big');
    expect(
      serializeInline(text, [
        range('link', 4, 9, 'https://a.example'),
        range('strong', 4, 9),
      ])
    ).toBe('The **[world](https://a.example)** is big');
  });

  it('trims delimiters to hug non-whitespace content', () => {
    // The range covers " world " including both spaces.
    expect(serializeInline('The world is big', [range('strong', 3, 10)])).toBe(
      'The **world** is big'
    );
    // A whitespace-only range serializes no delimiters at all.
    expect(serializeInline('a b', [range('strong', 1, 2)])).toBe('a b');
  });

  it('closes before opening at a shared boundary instead of nesting', () => {
    // "ab" with bold on "a" and underline on "b" — adjacent, not nested.
    expect(
      serializeInline('ab', [range('strong', 0, 1), range('underline', 1, 2)])
    ).toBe('**a**_b_');
  });
});

const prefix = markdownLinePrefix;

describe('serialize', () => {
  const text = 'Rebase\nfetch\nmerge';

  it('prefixes each block line with its marker', () => {
    const blocks = [
      createBlockRange('h2', 0, 6, 2),
      createBlockRange('ordered-list-item', 7, 12),
      { ...createBlockRange('ordered-list-item', 13, 18), ordinal: 2 },
    ];

    expect(serialize(text, [], blocks, prefix)).toBe(
      '## Rebase\n1. fetch\n2. merge'
    );
  });

  it('combines block prefixes with inline delimiters', () => {
    const blocks = [createBlockRange('ordered-list-item', 7, 12)];
    const bold = [{ type: 'strong' as const, start: 7, end: 12 }];

    expect(serialize(text, bold, blocks, prefix)).toBe(
      'Rebase\n1. **fetch**\nmerge'
    );
  });

  it('prefixes an empty heading anchor but leaves an empty list item bare', () => {
    const anchorText = `a\n${ZWSP}\nb`;

    expect(
      serialize(anchorText, [], [createBlockRange('h1', 2, 3, 1)], prefix)
    ).toBe('a\n# \nb');
    expect(
      serialize(
        anchorText,
        [],
        [createBlockRange('unordered-list-item', 2, 3)],
        prefix
      )
    ).toBe('a\n\nb');
  });
});

describe('markdownLinePrefix', () => {
  it('builds heading, bullet and numbered markers with three-space nesting', () => {
    expect(markdownLinePrefix(createBlockRange('h3', 0, 5, 3))).toBe('### ');
    expect(markdownLinePrefix(createBlockRange('paragraph', 0, 5))).toBe('');
    expect(
      markdownLinePrefix(createBlockRange('unordered-list-item', 0, 5, 1))
    ).toBe('   - ');
    expect(
      markdownLinePrefix({
        ...createBlockRange('ordered-list-item', 0, 5, 2),
        ordinal: 3,
      })
    ).toBe('      3. ');
  });
});
