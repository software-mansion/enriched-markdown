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

    const result = parseResultFromAst(ast, 'merge **fast** now');

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

    const result = parseResultFromAst(ast, '[docs](https://git-scm.com)****');

    expect(result.formattingRanges).toEqual([
      range('link', 0, 4, 'https://git-scm.com'),
    ]);
  });

  it('emits heading blocks with their level, none for paragraphs', () => {
    const ast = node('Document', [
      node('Heading', [text('Rebase')], { level: '2' }),
      node('Paragraph', [text('fetch first')]),
    ]);

    const result = parseResultFromAst(ast, '## Rebase\n\nfetch first');

    expect(result.plainText).toBe('Rebase\n\nfetch first');
    expect(result.blockRanges).toEqual([block('h2', 0, 6, 2)]);
  });

  it('falls back to paragraph for an out-of-range heading level', () => {
    const ast = node('Document', [
      node('Heading', [text('broken')], { level: '9' }),
    ]);

    const result = parseResultFromAst(ast, 'broken');

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
      node('OrderedList', [node('ListItem', [text('merge')])]),
    ]);

    const result = parseResultFromAst(ast, '- stack\n   - review\n\n1. merge');

    expect(result.plainText).toBe('stack\nreview\n\nmerge');
    // Ranges are emitted on node exit, so a nested item precedes its parent;
    // BlockStore.setRanges sorts by start.
    expect(result.blockRanges).toEqual([
      block('unordered-list-item', 6, 12, 1),
      block('unordered-list-item', 0, 5, 0),
      block('ordered-list-item', 14, 19, 0),
    ]);
  });

  it('replays the source blank-line runs between top-level blocks', () => {
    const ast = node('Document', [
      node('Paragraph', [text('a')]),
      node('Paragraph', [text('b')]),
      node('Paragraph', [text('c')]),
    ]);

    // Three blank lines after "a", one after "b".
    const result = parseResultFromAst(ast, 'a\n\n\n\nb\n\nc');

    expect(result.plainText).toBe('a\n\n\n\nb\n\nc');
  });

  it('turns soft and hard breaks into newlines', () => {
    const ast = node('Document', [
      node('Paragraph', [text('pull'), node('SoftBreak'), text('push')]),
    ]);

    expect(parseResultFromAst(ast, 'pull\npush').plainText).toBe('pull\npush');
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
    // unavailable. The fallback reports the caller's markdown, not the
    // delimiter-completed form, so nothing the user never typed survives.
    parseMarkdownMock.mockRejectedValue(new Error('WASM unavailable'));

    await expect(parseToPlainTextAndRanges('**force push')).resolves.toEqual({
      plainText: '**force push',
      formattingRanges: [],
      blockRanges: [],
    });
    expect(parseMarkdownMock).toHaveBeenCalledWith(
      '**force push**',
      expect.objectContaining({ permissiveAutolinks: false })
    );
  });
});
