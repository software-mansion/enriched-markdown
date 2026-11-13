import { markInlineImages } from '../src/web/utils';
import type { ASTNode } from '../src/web/types';

const image = (): ASTNode => ({
  type: 'Image',
  attributes: { url: 'https://example.com/thumb.jpg' },
});
const text = (content: string): ASTNode => ({ type: 'Text', content });

const isInline = (node: ASTNode) => node.attributes?.isInline;

describe('markInlineImages', () => {
  it('keeps an image that is the only child of a paragraph as a block', () => {
    const img = image();
    markInlineImages({ type: 'Paragraph', children: [img] });

    expect(isInline(img)).toBeUndefined();
  });

  it('marks an image next to text in a paragraph as inline', () => {
    const img = image();
    markInlineImages({ type: 'Paragraph', children: [text('a '), img] });

    expect(isInline(img)).toBe(true);
  });

  it('marks an image inside a link next to text as inline', () => {
    const img = image();
    const link: ASTNode = {
      type: 'Link',
      attributes: { url: 'https://example.com/games/1' },
      children: [img, text(' Catan')],
    };
    markInlineImages({
      type: 'Paragraph',
      children: [text('Play '), link, text(' tonight')],
    });

    expect(isInline(img)).toBe(true);
  });

  it('marks an image inside emphasis next to text as inline', () => {
    const img = image();
    markInlineImages({
      type: 'Paragraph',
      children: [text('a '), { type: 'Emphasis', children: [text('b '), img] }],
    });

    expect(isInline(img)).toBe(true);
  });

  it('keeps a link that holds only an image as a block', () => {
    const img = image();
    markInlineImages({
      type: 'Paragraph',
      children: [
        {
          type: 'Link',
          attributes: { url: 'https://example.com' },
          children: [img],
        },
      ],
    });

    expect(isInline(img)).toBeUndefined();
  });
});
