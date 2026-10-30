import { renderToStaticMarkup } from 'react-dom/server';
import { RenderNode } from '../src/web/renderers';
import { normalizeMarkdownStyle } from '../src/normalizeMarkdownStyle.web';
import { buildStyles } from '../src/web/styles';
import type { ASTNode, RenderCapabilities } from '../src/web/types';

const text = (content: string): ASTNode => ({ type: 'Text', content });
const node = (
  type: ASTNode['type'],
  children: ASTNode[] = [],
  attributes?: ASTNode['attributes']
): ASTNode => ({ type, children, attributes });

const doc = [
  node('Paragraph', [text('مرحبا')]),
  node('Heading', [text('عنوان')], { level: '2' }),
  node('Blockquote', [node('Paragraph', [text('اقتباس')])]),
  node('UnorderedList', [
    node('ListItem', [
      node('Paragraph', [text('بند')]),
      node('UnorderedList', [node('ListItem', [text('nested')])]),
    ]),
  ]),
  node('Table', [
    node('TableHead', [
      node('TableRow', [node('TableHeaderCell', [text('الاسم')])]),
    ]),
  ]),
  node('CodeBlock', [text('code')]),
  node('Paragraph', [text('123')]),
];

// Reviewer cases: nested quote, table inside a quote, code inside a quote.
const nestedDoc = [
  node('Blockquote', [
    node('Blockquote', [node('Paragraph', [text('مرحبا')])]),
    node('Table', [
      node('TableHead', [
        node('TableRow', [node('TableHeaderCell', [text('cell')])]),
      ]),
    ]),
    node('CodeBlock', [text('code')]),
  ]),
];

const admonition = node('Admonition', [node('Paragraph', [text('تنبيه')])], {
  admonitionType: 'note',
});

// Blocks that open with another block, and blocks with no letters to read.
const edgeDoc = [
  admonition,
  node('Blockquote', [admonition]),
  node('UnorderedList', [
    node('ListItem', [node('Blockquote', [node('Paragraph', [text('عربي')])])]),
  ]),
  node('Blockquote', [node('CodeBlock', [text('npm i')])]),
  node('Heading', [text('2026')], { level: '2' }),
];

function html(
  blockDir: RenderCapabilities['blockDir'],
  nodes: ASTNode[] = doc
): string {
  const style = normalizeMarkdownStyle({});
  return renderToStaticMarkup(
    <>
      {nodes.map((child, i) => (
        <RenderNode
          key={i}
          node={child}
          style={style}
          styles={buildStyles(style)}
          callbacks={{}}
          capabilities={{
            katex: null,
            enableTaskListItemToggle: true,
            blockDir,
          }}
        />
      ))}
    </>
  );
}

describe('web renderer direction', () => {
  it('gives each top-level block dir="auto" so it resolves from its content', () => {
    const out = html('auto');
    for (const tag of ['p', 'h2', 'blockquote', 'ul', 'th']) {
      expect(out).toMatch(new RegExp(`<${tag}[^>]*dir="auto"`));
    }
    // Nested blocks inherit, or they would hide their text from the parent's
    // first-strong scan (quote border / list marker on the wrong side).
    // A paragraph with no letters inherits instead of resolving to LTR.
    expect(out.match(/dir="auto"/g)).toHaveLength(5);
    expect(out).toMatch(/<pre[^>]*dir="ltr"/);
  });

  it('lets only the outermost block of a nested one resolve', () => {
    const out = html('auto', nestedDoc);
    expect(out.match(/dir="auto"/g)).toEqual(['dir="auto"']);
    expect(out).toMatch(/^<blockquote[^>]*dir="auto"/);
    // Code is skipped by the quote's scan.
    expect(out).toMatch(/<pre[^>]*dir="ltr"/);
  });

  it('gives the outer block a direction when it opens with a nested one', () => {
    const out = html('auto', edgeDoc);
    // The admonition, the quote around the second one, and the list.
    expect(out.match(/dir="auto"/g)).toHaveLength(3);
    expect(out).toMatch(/^<div[^>]*dir="auto"/);
    expect(out).toMatch(
      /<blockquote[^>]*dir="auto"[^>]*><div(?![^>]*dir="auto")/
    );
    expect(out).toMatch(/<ul[^>]*dir="auto"/);
    // The admonition title never decides the box's direction.
    expect(out.match(/<span dir="ltr">Note<\/span>/g)).toHaveLength(2);
  });

  it('lets a block whose only letters are code or digits inherit', () => {
    const out = html('auto', edgeDoc);
    expect(out).not.toMatch(/<blockquote[^>]*dir="auto"[^>]*><pre/);
    expect(out).not.toMatch(/<h2[^>]*dir=/);
  });

  it('leaves blocks to inherit a forced root direction', () => {
    expect(html(undefined)).not.toMatch(/dir="auto"/);
  });

  it('aligns unaligned table cells to the start edge', () => {
    expect(html('auto')).toMatch(/<th[^>]*text-align:start/);
  });
});
