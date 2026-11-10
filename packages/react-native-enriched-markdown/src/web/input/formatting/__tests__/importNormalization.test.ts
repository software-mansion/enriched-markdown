import { loadParser } from '../../../parseMarkdown';
import { parseToPlainTextAndRanges } from '../InputParser';

// Import and export run in the WASM core, which loads asynchronously.
beforeAll(() => loadParser());

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
