import { recognizeTextLinks } from '../src/web/recognizeTextLinks';
import type { ASTNode } from '../src/web/types';

const text = (content: string): ASTNode => ({ type: 'Text', content });
const node = (type: ASTNode['type'], ...children: ASTNode[]): ASTNode => ({
  type,
  children,
});
const document = (...children: ASTNode[]) =>
  node('Document', node('Paragraph', ...children));
const link = (url: string, child: ASTNode): ASTNode => ({
  type: 'Link',
  attributes: { url, recognizedLink: 'true' },
  children: [child],
});

function links(root: ASTNode): ASTNode[] {
  const own = root.type === 'Link' ? [root] : [];
  return own.concat((root.children ?? []).flatMap(links));
}

function originalText(root: ASTNode): string {
  return (
    (root.content ?? '') + (root.children ?? []).map(originalText).join('')
  );
}

describe('recognizeTextLinks (web)', () => {
  it('returns the same tree when both patterns are absent or invalid', () => {
    const ast = document(text('item-12'));
    expect(recognizeTextLinks(ast, undefined, undefined)).toBe(ast);
    // A pattern that is valid elsewhere but not for this engine arrives as a plain object.
    const invalid = { source: '(', ignoreCase: false, dotAll: false } as RegExp;
    expect(recognizeTextLinks(ast, invalid, invalid)).toBe(ast);
  });

  it('splits text runs around every nonempty match and keeps the text', () => {
    const ast = document(text('Before item-12, item-34 after.'));
    const actual = recognizeTextLinks(ast, /item-\d+/, undefined);
    expect(actual).toEqual(
      document(
        text('Before '),
        link('item-12', text('item-12')),
        text(', '),
        link('item-34', text('item-34')),
        text(' after.')
      )
    );
    expect(originalText(actual)).toBe(originalText(ast));
  });

  it('ignores empty matches', () => {
    const ast = document(text('abc xx def'));
    expect(
      links(recognizeTextLinks(ast, /x*/, undefined)).map(
        (l) => l.attributes?.url
      )
    ).toEqual(['xx']);
    expect(recognizeTextLinks(ast, /(?=x)/, undefined)).toBe(ast);
  });

  it('leaves links, code blocks, media and math untouched', () => {
    const explicit: ASTNode = {
      type: 'Link',
      attributes: { url: 'https://original.invalid' },
      children: [text('item-12')],
    };
    const opaque = (
      ['CodeBlock', 'Image', 'Video', 'LatexMathInline'] as const
    ).map((type) => node(type, text('item-12')));
    const ast = node(
      'Document',
      node('Paragraph', explicit, text(' item-78 '), ...opaque)
    );
    const actual = recognizeTextLinks(ast, /item-\d+/, /item-\d+/);
    expect(links(actual).map((l) => l.attributes?.url)).toEqual([
      'https://original.invalid',
      'item-78',
    ]);
  });

  it('recognizes inline code only when the whole span matches', () => {
    const whole = node('Code', text('item-'), text('12'));
    const partial = node('Code', text('see item-12'));
    const actual = recognizeTextLinks(
      document(whole, partial),
      undefined,
      /item-\d+|a/
    );
    expect(actual).toEqual(document(link('item-12', whole), partial));
    expect(links(actual)[0]?.children?.[0]).toBe(whole);
  });

  it('honors only the i and s flags', () => {
    const ast = document(text('ITEM-12'), node('Code', text('a\nb')));
    const insensitive = recognizeTextLinks(ast, /item-\d+/gi, /a.b/);
    expect(links(insensitive).map((l) => l.attributes?.url)).toEqual([
      'ITEM-12',
    ]);
    const dotAll = recognizeTextLinks(ast, undefined, /a.b/s);
    expect(links(dotAll).map((l) => l.attributes?.url)).toEqual(['a\nb']);
  });

  it('keeps untouched subtrees by identity', () => {
    const untouched = node('Paragraph', text('nothing here'));
    const ast = node('Document', untouched, node('Paragraph', text('item-12')));
    const actual = recognizeTextLinks(ast, /item-\d+/, undefined);
    expect(actual).not.toBe(ast);
    expect(actual.children?.[0]).toBe(untouched);
  });
});
