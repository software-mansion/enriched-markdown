import { parseResultFromAst, parseToPlainTextAndRanges } from '../InputParser';
import { parseMarkdown } from '../../../parseMarkdown';
import { createFormattingRange as range } from '../../model/inlineStyles';
import { createBlockRange as block } from '../../model/blocks';
import type { ASTNode, NodeAttributes, NodeType } from '../../../types';

jest.mock('../../../parseMarkdown', () => ({ parseMarkdown: jest.fn() }));

const parseMarkdownMock = parseMarkdown as jest.MockedFunction<
  typeof parseMarkdown
>;

const node = (
  type: NodeType,
  children: ASTNode[] = [],
  attributes?: NodeAttributes
): ASTNode => ({ type, children, attributes });

const text = (content: string): ASTNode => ({ type: 'Text', content });

// md4c's report of `count` blank source lines (`preserveBlankLines`).
const blank = (count: number): ASTNode =>
  node('BlankLine', [], { count: String(count) });

describe('parseResultFromAst', () => {
  it('accumulates plain text and turns style nodes into ranges', () => {
    // "merge **fast** now" — delimiters live in the AST, not the text.
    const ast = node('Document', [
      node('Paragraph', [
        text('merge '),
        node('Strong', [text('fast')]),
        text(' now'),
      ]),
    ]);

    const result = parseResultFromAst(ast);

    expect(result.plainText).toBe('merge fast now');
    expect(result.formattingRanges).toEqual([range('strong', 6, 10)]);
    expect(result.blockRanges).toEqual([]);
  });

  it('captures the link url and drops a style over empty content', () => {
    const ast = node('Document', [
      node('Paragraph', [
        node('Link', [text('docs')], { url: 'https://git-scm.com' }),
        node('Strong', []),
      ]),
    ]);

    const result = parseResultFromAst(ast);

    expect(result.formattingRanges).toEqual([
      range('link', 0, 4, 'https://git-scm.com'),
    ]);
  });

  it('emits heading blocks with their level, none for paragraphs', () => {
    const ast = node('Document', [
      node('Heading', [text('Rebase')], { level: '2' }),
      blank(1),
      node('Paragraph', [text('fetch first')]),
    ]);

    const result = parseResultFromAst(ast);

    expect(result.plainText).toBe('Rebase\n\nfetch first');
    expect(result.blockRanges).toEqual([block('h2', 0, 6, 2)]);
  });

  it('falls back to paragraph for an out-of-range heading level', () => {
    const ast = node('Document', [
      node('Heading', [text('broken')], { level: '9' }),
    ]);

    const result = parseResultFromAst(ast);

    expect(result.plainText).toBe('broken');
    expect(result.blockRanges).toEqual([]);
  });

  it('gives list items first-line bounds and AST-derived depths', () => {
    // - stack
    //    - review
    // 1. merge   (separate list, so a fresh ordered container)
    const ast = node('Document', [
      node('UnorderedList', [
        node('ListItem', [
          text('stack'),
          node('UnorderedList', [node('ListItem', [text('review')])]),
        ]),
      ]),
      blank(1),
      node('OrderedList', [node('ListItem', [text('merge')])]),
    ]);

    const result = parseResultFromAst(ast);

    expect(result.plainText).toBe('stack\nreview\n\nmerge');
    // Ranges are emitted on node exit, so a nested item precedes its parent;
    // the result is sorted by start on the way out.
    expect(result.blockRanges).toEqual([
      block('unordered-list-item', 0, 5, 0),
      block('unordered-list-item', 6, 12, 1),
      block('ordered-list-item', 14, 19, 0),
    ]);
  });

  it('gives each blank source line an empty line between blocks', () => {
    // Three blank lines after "a", one after "b", none before the heading.
    const ast = node('Document', [
      node('Paragraph', [text('a')]),
      blank(3),
      node('Paragraph', [text('b')]),
      blank(1),
      node('Paragraph', [text('c')]),
      node('Heading', [text('d')], { level: '1' }),
    ]);

    expect(parseResultFromAst(ast).plainText).toBe('a\n\n\n\nb\n\nc\nd');
  });

  it('drops blank lines before the first block and after the last', () => {
    const ast = node('Document', [
      blank(2),
      node('Paragraph', [text('a')]),
      blank(2),
    ]);

    expect(parseResultFromAst(ast).plainText).toBe('a');
  });

  it('keeps blank lines between list items where they stood', () => {
    // - a
    //
    //
    // - b
    //
    // c
    const ast = node('Document', [
      node('UnorderedList', [
        node('ListItem', [node('Paragraph', [text('a')]), blank(2)]),
        node('ListItem', [node('Paragraph', [text('b')]), blank(1)]),
      ]),
      node('Paragraph', [text('c')]),
    ]);

    const result = parseResultFromAst(ast);

    expect(result.plainText).toBe('a\n\n\nb\n\nc');
    expect(result.blockRanges).toEqual([
      block('unordered-list-item', 0, 1, 0),
      block('unordered-list-item', 4, 5, 0),
    ]);
  });

  it("does not count an empty item's own line as a blank one", () => {
    // "- \n\n- b": md4c reports the empty item's line and the blank line
    // after it as one run of two, first in the item.
    const ast = node('Document', [
      node('UnorderedList', [
        node('ListItem', [blank(2)]),
        node('ListItem', [node('Paragraph', [text('b')])]),
      ]),
    ]);

    const result = parseResultFromAst(ast);

    expect(result.plainText).toBe('\n\nb');
    expect(result.blockRanges).toEqual([
      block('unordered-list-item', 0, 0, 0),
      block('unordered-list-item', 2, 3, 0),
    ]);
  });

  it('drops a blank line above a nested item rather than de-nesting it', () => {
    // - a
    //   - b
    //
    //   - c
    const ast = node('Document', [
      node('UnorderedList', [
        node('ListItem', [
          node('Paragraph', [text('a')]),
          node('UnorderedList', [
            node('ListItem', [node('Paragraph', [text('b')]), blank(1)]),
            node('ListItem', [node('Paragraph', [text('c')])]),
          ]),
        ]),
      ]),
    ]);

    expect(parseResultFromAst(ast).plainText).toBe('a\nb\nc');
  });

  it('turns soft and hard breaks into newlines', () => {
    const ast = node('Document', [
      node('Paragraph', [text('pull'), node('SoftBreak'), text('push')]),
    ]);

    expect(parseResultFromAst(ast).plainText).toBe('pull\npush');
  });

  it('starts a list on the top-level break without an extra newline', () => {
    const ast = node('Document', [
      node('Paragraph', [text('intro')]),
      blank(1),
      node('UnorderedList', [
        node('ListItem', [node('Paragraph', [text('fetch')])]),
        node('ListItem', [node('Paragraph', [text('merge')]), blank(2)]),
      ]),
      node('Paragraph', [text('done')]),
    ]);

    const result = parseResultFromAst(ast);

    expect(result.plainText).toBe('intro\n\nfetch\nmerge\n\n\ndone');
    expect(result.blockRanges).toEqual([
      block('unordered-list-item', 7, 12, 0),
      block('unordered-list-item', 13, 18, 0),
    ]);
  });

  it("puts an item's further paragraphs on their own lines", () => {
    // - fetch
    //
    //   then rebase
    // - push
    const ast = node('Document', [
      node('UnorderedList', [
        node('ListItem', [
          node('Paragraph', [text('fetch')]),
          blank(1),
          node('Paragraph', [text('then rebase')]),
        ]),
        node('ListItem', [node('Paragraph', [text('push')])]),
      ]),
    ]);

    const result = parseResultFromAst(ast);

    expect(result.plainText).toBe('fetch\n\nthen rebase\npush');
    expect(result.blockRanges).toEqual([
      block('unordered-list-item', 0, 5, 0),
      block('unordered-list-item', 19, 23, 0),
    ]);
  });

  it("ends an item's range at a soft break inside its paragraph", () => {
    // "- fetch\n then rebase": a lazy continuation of the item's paragraph.
    const ast = node('Document', [
      node('UnorderedList', [
        node('ListItem', [
          node('Paragraph', [
            text('fetch'),
            node('SoftBreak'),
            text('then rebase'),
          ]),
        ]),
      ]),
    ]);

    const result = parseResultFromAst(ast);

    expect(result.plainText).toBe('fetch\nthen rebase');
    expect(result.blockRanges).toEqual([block('unordered-list-item', 0, 5, 0)]);
  });

  it('keeps an empty item as a zero-length range on its own line', () => {
    const ast = node('Document', [
      node('OrderedList', [
        node('ListItem', [node('Paragraph', [text('fetch')])]),
        node('ListItem'),
        node('ListItem', [node('Paragraph', [text('push')])]),
      ]),
    ]);

    const result = parseResultFromAst(ast);

    expect(result.plainText).toBe('fetch\n\npush');
    expect(result.blockRanges).toEqual([
      block('ordered-list-item', 0, 5, 0),
      block('ordered-list-item', 6, 6, 0),
      block('ordered-list-item', 7, 11, 0),
    ]);
  });
});

describe('parseToPlainTextAndRanges', () => {
  afterEach(() => {
    parseMarkdownMock.mockReset();
  });

  it('short-circuits empty input without reaching the parser', async () => {
    await expect(parseToPlainTextAndRanges('')).resolves.toEqual({
      plainText: '',
      formattingRanges: [],
      blockRanges: [],
    });
    expect(parseMarkdownMock).not.toHaveBeenCalled();
  });

  it('degrades to unformatted text when the parser rejects', async () => {
    // A library must not crash the host app when the WASM parser is
    // unavailable.
    parseMarkdownMock.mockRejectedValue(new Error('WASM unavailable'));

    await expect(parseToPlainTextAndRanges('**force push')).resolves.toEqual({
      plainText: '**force push',
      formattingRanges: [],
      blockRanges: [],
    });
  });

  it('hands the parser the markdown as given, without closing delimiters', async () => {
    // An unclosed delimiter is literal text, not a half-typed span: closing
    // it would turn "snake_case" into "snake_case_" and "2*3" into emphasis.
    parseMarkdownMock.mockResolvedValue({ type: 'Document', children: [] });

    await parseToPlainTextAndRanges('**force push');
    expect(parseMarkdownMock).toHaveBeenCalledWith(
      '**force push',
      expect.objectContaining({ permissiveAutolinks: false })
    );
  });
});
