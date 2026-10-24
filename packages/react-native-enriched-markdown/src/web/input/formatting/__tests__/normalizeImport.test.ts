import { parseToPlainTextAndRanges } from '../InputParser';
import {
  normalizeBlockRanges,
  normalizeFormattingRanges,
} from '../normalizeImport';
import { createBlockRange as block } from '../../model/blocks';
import { createFormattingRange as range } from '../../model/inlineStyles';

// What md4c reports for these breaks the stores' invariants; the import
// restores them before an edit can trip over it (review §2.3.4).
describe('import normalization', () => {
  const summary = async (markdown: string) => {
    const result = await parseToPlainTextAndRanges(markdown);
    return {
      text: result.plainText,
      formatting: result.formattingRanges.map(
        (r) => `${r.type}:${r.start}-${r.end}${r.url ? `(${r.url})` : ''}`
      ),
      blocks: result.blockRanges.map(
        (b) => `${b.type}:${b.start}-${b.end}/${b.level}`
      ),
    };
  };

  it('splits a setext heading over two lines into one heading per line', async () => {
    expect(await summary('Foo\nbar\n===')).toEqual({
      text: 'Foo\nbar',
      formatting: [],
      blocks: ['h1:0-3/1', 'h1:4-7/1'],
    });
  });

  it('keeps the list item of a heading inside one', async () => {
    expect(await summary('- # foo')).toEqual({
      text: 'foo',
      formatting: [],
      blocks: ['unordered-list-item:0-3/0'],
    });
    expect((await summary('1. # h\n2. x')).blocks).toEqual([
      'ordered-list-item:0-1/0',
      'ordered-list-item:2-3/0',
    ]);
  });

  it('merges nested same-type styles', async () => {
    expect((await summary('**foo **bar** baz**')).formatting).toEqual([
      'strong:0-11',
    ]);
  });

  it('merges touching links only when their urls match', async () => {
    expect((await summary('[a](x)[b](x)')).formatting).toEqual(['link:0-2(x)']);
    expect((await summary('[a](x)[b](y)')).formatting).toEqual([
      'link:0-1(x)',
      'link:1-2(y)',
    ]);
  });

  it('leaves styles of different types and separate same-type styles alone', async () => {
    expect((await summary('*a* *b* **c**')).formatting).toEqual([
      'em:0-1',
      'em:2-3',
      'strong:4-5',
    ]);
  });
});

describe('normalizeImport', () => {
  it('copies a block spanning lines onto each, at line bounds', () => {
    expect(
      normalizeBlockRanges('ab\ncd\n', [{ ...block('h2', 0, 5), level: 2 }])
    ).toEqual([
      { ...block('h2', 0, 2), level: 2 },
      { ...block('h2', 3, 5), level: 2 },
    ]);
  });

  it('keeps a zero-length anchor on its empty line', () => {
    expect(
      normalizeBlockRanges('a\n\nb', [block('unordered-list-item', 2, 2)])
    ).toEqual([block('unordered-list-item', 2, 2)]);
  });

  it('prefers a list item over a heading over a paragraph on one line', () => {
    expect(
      normalizeBlockRanges('ab', [
        block('paragraph', 0, 2),
        { ...block('h1', 0, 2), level: 1 },
        block('ordered-list-item', 0, 2),
        { ...block('h3', 0, 2), level: 3 },
      ])
    ).toEqual([block('ordered-list-item', 0, 2)]);
  });

  it('merges overlapping and touching same-type ranges, sorted by start', () => {
    expect(
      normalizeFormattingRanges([
        range('strong', 4, 7),
        range('em', 1, 2),
        range('strong', 0, 4),
        range('strong', 6, 9),
        range('strong', 11, 12),
      ])
    ).toEqual([
      range('strong', 0, 9),
      range('em', 1, 2),
      range('strong', 11, 12),
    ]);
  });

  it('drops empty ranges', () => {
    expect(normalizeFormattingRanges([range('em', 3, 3)])).toEqual([]);
  });
});
