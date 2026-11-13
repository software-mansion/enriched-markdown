import { loadParser } from '../../../parseMarkdown';
import { parseToPlainTextAndRanges } from '../InputParser';
import { createFormattingRange as range } from '../../model/inlineStyles';
import { createBlockRange as block } from '../../model/blocks';

// The import itself is tested in C++ (cpp/tests/input) and, through the WASM
// build, in markdownRoundTrip and importNormalization; this covers the wrapper.

describe('parseToPlainTextAndRanges', () => {
  beforeAll(() => loadParser());

  it('short-circuits empty input', async () => {
    await expect(parseToPlainTextAndRanges('')).resolves.toEqual({
      plainText: '',
      formattingRanges: [],
      blockRanges: [],
    });
  });

  it('returns plain text, UTF-16 ranges and blocks', async () => {
    await expect(
      parseToPlainTextAndRanges('# 😀 **bold**\n- [日本](https://x.dev)')
    ).resolves.toEqual({
      plainText: '😀 bold\n日本',
      formattingRanges: [
        range('strong', 3, 7),
        range('link', 8, 10, 'https://x.dev'),
      ],
      blockRanges: [
        { ...block('h1', 0, 7), level: 1 },
        block('unordered-list-item', 8, 10),
      ],
    });
  });

  it('numbers ordered items the way the block store does', async () => {
    const { blockRanges } = await parseToPlainTextAndRanges('9. a\n7. b\n1. c');

    expect(blockRanges.map((b) => b.ordinal)).toEqual([1, 2, 3]);
  });

  it('keeps an unclosed delimiter as literal text', async () => {
    // Closing it would turn "snake_case" into "snake_case_" and "2*3" into
    // emphasis.
    await expect(parseToPlainTextAndRanges('**force push')).resolves.toEqual({
      plainText: '**force push',
      formattingRanges: [],
      blockRanges: [],
    });
    expect((await parseToPlainTextAndRanges('snake_case 2*3')).plainText).toBe(
      'snake_case 2*3'
    );
  });
});

describe('parseToPlainTextAndRanges without the WASM module', () => {
  it('degrades to unformatted text', async () => {
    // A library must not crash the host app when the module is unavailable.
    jest.resetModules();
    jest.doMock('../../../wasm/md4c', () => ({
      __esModule: true,
      default: () => Promise.reject(new Error('WASM unavailable')),
    }));
    const { parseToPlainTextAndRanges: parse } = require('../InputParser');

    await expect(parse('**force push')).resolves.toEqual({
      plainText: '**force push',
      formattingRanges: [],
      blockRanges: [],
    });
    jest.dontMock('../../../wasm/md4c');
  });
});
