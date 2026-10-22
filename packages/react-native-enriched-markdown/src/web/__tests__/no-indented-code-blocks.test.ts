import { parseMarkdown } from '../parseMarkdown';
import type { ASTNode } from '../types';

function count(node: ASTNode, type: string): number {
  return (
    Number(node.type === type) +
    (node.children ?? []).reduce(
      (total, child) => total + count(child, type),
      0
    )
  );
}

it('preserves default indented code and supports repeated opt-in parses with both fences', async () => {
  const markdown =
    '    **spaces**\n\nSeparator.\n\n\t*tab*\n\n```js\nfenced\n```\n\n~~~\ntilde\n~~~';
  for (const enabled of [undefined, false, true, false]) {
    const ast = await parseMarkdown(markdown, {
      noIndentedCodeBlocks: enabled,
    });
    expect(count(ast, 'CodeBlock')).toBe(enabled ? 2 : 4);
    expect(count(ast, 'Strong')).toBe(enabled ? 1 : 0);
    expect(count(ast, 'Emphasis')).toBe(enabled ? 1 : 0);
  }
});

it('keeps list and blockquote containers while opting their indented content out of code', async () => {
  for (const enabled of [false, true, false]) {
    const ast = await parseMarkdown(
      '- item\n\n      **nested**\n\n>     *quoted*',
      {
        noIndentedCodeBlocks: enabled,
      }
    );
    expect(count(ast, 'UnorderedList')).toBe(1);
    expect(count(ast, 'Blockquote')).toBe(1);
    expect(count(ast, 'CodeBlock')).toBe(enabled ? 0 : 2);
    expect(count(ast, 'Strong')).toBe(enabled ? 1 : 0);
    expect(count(ast, 'Emphasis')).toBe(enabled ? 1 : 0);
  }
});

it('keeps noIndentedCodeBlocks independent of permissiveAutolinks', async () => {
  const markdown = '    **prose**\n\nhttps://git-scm.com';
  for (const noIndentedCodeBlocks of [false, true]) {
    for (const permissiveAutolinks of [false, true]) {
      const ast = await parseMarkdown(markdown, {
        noIndentedCodeBlocks,
        permissiveAutolinks,
      });
      expect(count(ast, 'CodeBlock')).toBe(noIndentedCodeBlocks ? 0 : 1);
      expect(count(ast, 'Strong')).toBe(noIndentedCodeBlocks ? 1 : 0);
      expect(count(ast, 'Link')).toBe(permissiveAutolinks ? 1 : 0);
    }
  }
});
