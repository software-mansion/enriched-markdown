import { parseMarkdown } from '../parseMarkdown';
import type { ASTNode } from '../types';

function nodeTypes(node: ASTNode): string[] {
  return [node.type, ...(node.children ?? []).flatMap(nodeTypes)];
}

const BARE_URL = 'see https://git-scm.com for more';

describe('parseMarkdown permissiveAutolinks', () => {
  it('autolinks bare URLs by default', async () => {
    const ast = await parseMarkdown(BARE_URL);

    expect(nodeTypes(ast)).toContain('Link');
  });

  it('leaves bare URLs as text when disabled', async () => {
    const ast = await parseMarkdown(BARE_URL, { permissiveAutolinks: false });

    expect(nodeTypes(ast)).not.toContain('Link');
  });

  it('still parses explicit links when disabled', async () => {
    // The flag only governs bracket-less URLs - the web input editor turns it
    // off so its own autolink layer owns bare URLs, and must keep real links.
    const ast = await parseMarkdown('read the [docs](https://git-scm.com)', {
      permissiveAutolinks: false,
    });

    expect(nodeTypes(ast)).toContain('Link');
  });
});

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

describe('parseMarkdown LaTeX math', () => {
  it('uses the same AST for bracket and dollar delimiters', async () => {
    expect(await parseMarkdown(String.raw`Answer: \(x_1 + 1\).`)).toEqual(
      await parseMarkdown('Answer: $x_1 + 1$.')
    );
    expect(await parseMarkdown(String.raw`\[x^2 + y^2 = z^2\]`)).toEqual(
      await parseMarkdown('$$x^2 + y^2 = z^2$$')
    );
  });

  it('disables every delimiter form with the existing math flag', async () => {
    const ast = await parseMarkdown(String.raw`\(x\) \[y\] $z$ $$w$$`, {
      latexMath: false,
    });
    expect(find(ast, 'LatexMathInline')).toBeUndefined();
    expect(find(ast, 'LatexMathDisplay')).toBeUndefined();
    expect(texts(ast)).toEqual(['(x) [y] $z$ $$w$$']);
  });

  it('keeps incomplete streamed delimiters as ordinary text', async () => {
    for (const source of [
      String.raw`\(x_1 + 1\)`,
      String.raw`\[x^2 + y^2 = z^2\]`,
    ]) {
      for (let length = 1; length < source.length; length++) {
        const ast = await parseMarkdown(source.slice(0, length));
        expect(find(ast, 'LatexMathInline')).toBeUndefined();
        expect(find(ast, 'LatexMathDisplay')).toBeUndefined();
      }
    }
  });

  it('preserves doubled backslashes and code while accepting mixed math', async () => {
    for (const source of [String.raw`\\(x\\) \\[y\\]`, '\\']) {
      const ast = await parseMarkdown(source);
      expect(find(ast, 'LatexMathInline')).toBeUndefined();
      expect(find(ast, 'LatexMathDisplay')).toBeUndefined();
    }
    const code = await parseMarkdown('`\\(x\\) \\[y\\]`');
    expect(texts(code)).toEqual([String.raw`\(x\) \[y\]`]);
    const mixed = await parseMarkdown(String.raw`$a$ \(b\) $$c$$ \[d\]`);
    expect(mixed).toEqual(await parseMarkdown('$a$ $b$ $$c$$ $$d$$'));
  });
});
