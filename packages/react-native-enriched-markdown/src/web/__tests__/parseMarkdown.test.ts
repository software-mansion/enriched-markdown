import { parseMarkdown } from '../parseMarkdown';
import type { ASTNode } from '../types';

function texts(node: ASTNode): string[] {
  const own =
    typeof node.content === 'string' && node.content ? [node.content] : [];
  return own.concat((node.children ?? []).flatMap(texts));
}

function find(node: ASTNode, type: string): ASTNode | undefined {
  if (node.type === type) return node;
  for (const child of node.children ?? []) {
    const hit = find(child, type);
    if (hit) return hit;
  }
  return undefined;
}

describe('parseMarkdown character references', () => {
  it('decodes named and numeric references in text', async () => {
    expect(
      texts(await parseMarkdown('Tom &amp; Jerry &copy; &#169; &#xA9;'))
    ).toEqual(['Tom & Jerry © © ©']);
  });

  it('decodes two-codepoint entities', async () => {
    expect(texts(await parseMarkdown('&NotNestedGreaterGreater;'))).toEqual([
      '⪢̸',
    ]);
  });

  it('keeps unknown names, code spans and escapes literal', async () => {
    expect(
      texts(await parseMarkdown('&foo; and &amp `&amp;` \\&amp;'))
    ).toEqual(['&foo; and &amp ', '&amp;', ' &amp;']);
  });

  it('replaces invalid numeric references with U+FFFD', async () => {
    expect(texts(await parseMarkdown('&#0; &#xD800; &#x110000;'))).toEqual([
      '� � �',
    ]);
  });

  it('does not let decoded characters become syntax', async () => {
    const ast = await parseMarkdown('&lt;u&gt;x&lt;/u&gt; &#42;y&#42;');
    expect(find(ast, 'Underline')).toBeUndefined();
    expect(find(ast, 'Emphasis')).toBeUndefined();
    expect(texts(ast)).toEqual(['<u>x</u> *y*']);
  });

  it('decodes references in link and image attributes', async () => {
    const ast = await parseMarkdown(
      '[q](/u?a=1&amp;b=2 "t &amp; u") ![i](/p.png?x&amp;y "c &copy;")'
    );
    expect(find(ast, 'Link')?.attributes).toMatchObject({ url: '/u?a=1&b=2' });
    expect(find(ast, 'Image')?.attributes).toMatchObject({
      url: '/p.png?x&y',
      title: 'c ©',
    });
  });
});
