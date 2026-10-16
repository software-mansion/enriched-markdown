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
