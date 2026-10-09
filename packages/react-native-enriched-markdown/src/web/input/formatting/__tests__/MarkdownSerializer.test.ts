import {
  markdownLinePrefix,
  serialize,
  serializeInline,
} from '../MarkdownSerializer';
import { createBlockRange, MAX_LIST_DEPTH } from '../../model/blocks';
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

  it('closes and reopens a range on each line it covers', () => {
    // Delimiters may not cross a line: every line is its own block, so a
    // run left open would re-parse as literal asterisks.
    expect(serializeInline('foo\nbar', [range('strong', 0, 7)])).toBe(
      '**foo**\n**bar**'
    );
    // A blank line in the middle contributes no delimiters of its own.
    expect(serializeInline('foo\n\nbar', [range('em', 0, 8)])).toBe(
      '*foo*\n\n*bar*'
    );
    expect(
      serializeInline('foo\nbar', [range('link', 0, 7, 'https://a.example')])
    ).toBe('[foo](https://a.example)\n[bar](https://a.example)');
  });

  it('wraps a link destination that would end early', () => {
    const link = (url: string) =>
      serializeInline('docs', [range('link', 0, 4, url)]);

    expect(link('https://a.example/a b')).toBe(
      '[docs](<https://a.example/a b>)'
    );
    expect(link('https://a.example/a(b')).toBe(
      '[docs](<https://a.example/a(b>)'
    );
    // Balanced parens parse fine bare, so they stay bare.
    expect(link('https://a.example/a(b)c')).toBe(
      '[docs](https://a.example/a(b)c)'
    );
  });

  it('doubles a backslash in a link destination in both forms', () => {
    const link = (url: string) =>
      serializeInline('docs', [range('link', 0, 4, url)]);

    // Left bare, the trailing "\" would escape the closing ">".
    expect(link('https://a.example/a b\\')).toBe(
      '[docs](<https://a.example/a b\\\\>)'
    );
    // Bare destinations resolve escapes too, so "\*" would come back as "*".
    expect(link('https://a.example/a\\*b')).toBe(
      '[docs](https://a.example/a\\\\*b)'
    );
  });

  it('percent-encodes a line ending in a link destination', () => {
    expect(
      serializeInline('docs', [range('link', 0, 4, 'https://a.example/a\nb')])
    ).toBe('[docs](https://a.example/a%0Ab)');
    expect(
      serializeInline('docs', [range('link', 0, 4, 'https://a.example/a\r\nb')])
    ).toBe('[docs](https://a.example/a%0D%0Ab)');
  });
});

describe('serialize', () => {
  const text = 'Rebase\nfetch\nmerge';

  it('prefixes each block line with its marker', () => {
    const blocks = [
      createBlockRange('h2', 0, 6, 2),
      createBlockRange('ordered-list-item', 7, 12),
      { ...createBlockRange('ordered-list-item', 13, 18), ordinal: 2 },
    ];

    expect(serialize(text, [], blocks)).toBe('## Rebase\n1. fetch\n2. merge');
  });

  it('combines block prefixes with inline delimiters', () => {
    const blocks = [createBlockRange('ordered-list-item', 7, 12)];
    const bold = [{ type: 'strong' as const, start: 7, end: 12 }];

    expect(serialize(text, bold, blocks)).toBe('Rebase\n1. **fetch**\nmerge');
  });

  // The shape the block store produces: an emptied heading or list item keeps
  // its line as a zero-length range, the line itself holding no characters.
  it('prefixes an empty heading anchor but leaves an empty list item bare', () => {
    const anchorText = 'a\n\nb';

    expect(serialize(anchorText, [], [createBlockRange('h1', 2, 2, 1)])).toBe(
      'a\n# \nb'
    );
    expect(
      serialize(anchorText, [], [createBlockRange('unordered-list-item', 2, 2)])
    ).toBe('a\n\nb');
  });

  // A line ending in a url used to reach the output verbatim, breaking the
  // line-count invariant and dropping every block prefix in the document.
  it('keeps block prefixes when a link url carries a line ending', () => {
    const blocks = [
      createBlockRange('h1', 0, 6, 1),
      createBlockRange('unordered-list-item', 7, 12),
    ];
    const link = [range('link', 7, 12, 'https://a.example/a\nb')];

    expect(serialize(text, link, blocks)).toBe(
      '# Rebase\n- [fetch](https://a.example/a%0Ab)\nmerge'
    );
  });

  it('indents a nested item under a multi-digit ordered marker', () => {
    const nested = (ordinal: number) =>
      serialize(
        'a\nb',
        [],
        [
          { ...createBlockRange('ordered-list-item', 0, 1), ordinal },
          createBlockRange('unordered-list-item', 2, 3, 1),
        ]
      );

    // Three spaces clear "1. " but not "10. ", which would de-nest the child.
    expect(nested(1)).toBe('1. a\n   - b');
    expect(nested(10)).toBe('10. a\n    - b');
  });

  it('anchors the trailing empty line after a final newline', () => {
    expect(serialize('a\n', [], [createBlockRange('h1', 2, 2, 1)])).toBe(
      'a\n# '
    );
  });
});

describe('markdownLinePrefix', () => {
  // With no parent content column passed, nesting falls back to assuming
  // single-digit markers all the way up; `serialize` passes the real width.
  it('builds heading, bullet and numbered markers', () => {
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

  it('takes the heading level from the type, not from level', () => {
    expect(markdownLinePrefix(createBlockRange('h3', 0, 5))).toBe('### ');
    expect(markdownLinePrefix(createBlockRange('h6', 0, 5, 2))).toBe('###### ');
  });

  it('clamps list indentation to the deepest nesting the store allows', () => {
    expect(
      markdownLinePrefix(createBlockRange('unordered-list-item', 0, 5, 9))
    ).toBe('   '.repeat(MAX_LIST_DEPTH) + '- ');
  });
});
