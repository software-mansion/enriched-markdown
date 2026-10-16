import { act } from 'react';
import { createRoot } from 'test-renderer';
import { renderToStaticMarkup } from 'react-dom/server';
import { RenderNode } from '../src/web/renderers';
import { normalizeMarkdownStyle } from '../src/normalizeMarkdownStyle.web';
import { buildStyles } from '../src/web/styles';

const style = normalizeMarkdownStyle({});
const node = {
  type: 'CodeBlock' as const,
  attributes: { language: 'typescript' },
  children: [{ type: 'Text' as const, content: 'const value = 1;\n' }],
};

it('renders a code block using the supplied component and preserves source whitespace', () => {
  const html = renderToStaticMarkup(
    <RenderNode
      node={node}
      style={style}
      styles={buildStyles(style)}
      callbacks={{}}
      capabilities={{
        katex: null,
        enableTaskListItemToggle: true,
        renderers: {
          codeBlock: ({ code, language }) => (
            <section data-language={language}>
              <button>Copy</button>
              <pre>{code}</pre>
            </section>
          ),
        },
      }}
    />
  );
  expect(html).toBe(
    '<section data-language="typescript"><button>Copy</button><pre>const value = 1;\n</pre></section>'
  );
});

it('keeps the default code renderer when no override is supplied', () => {
  const html = renderToStaticMarkup(
    <RenderNode
      node={node}
      style={style}
      styles={buildStyles(style)}
      callbacks={{}}
      capabilities={{ katex: null, enableTaskListItemToggle: true }}
    />
  );
  expect(html).toContain('aria-label="Code block: typescript"');
  expect(html).toContain('const value = 1;\n</code></pre>');
});

it('preserves ordered-list starts and link titles in semantic web output', () => {
  const html = renderToStaticMarkup(
    <RenderNode
      node={{
        type: 'OrderedList',
        attributes: { start: '5' },
        children: [
          {
            type: 'Link',
            attributes: { url: 'https://example.com', title: 'Reference' },
            children: [{ type: 'Text', content: 'docs' }],
          },
        ],
      }}
      style={style}
      styles={buildStyles(style)}
      callbacks={{}}
      capabilities={{ katex: null, enableTaskListItemToggle: true }}
    />
  );
  expect(html).toContain('start="5"');
  expect(html).toContain('title="Reference"');
});

it.each(['markdown', 'text', 'inline-code'] as const)(
  'reports the tapped occurrence as %s even when URLs match',
  (sourceType) => {
    const calls: unknown[] = [];
    const tree = createRoot();
    act(() => {
      tree.render(
        <RenderNode
          node={{
            type: 'Link',
            attributes: {
              url: '/tmp/my%20file.ts',
              ...(sourceType === 'markdown' ? {} : { recognizedLink: 'true' }),
            },
            children: [
              {
                type: sourceType === 'inline-code' ? 'Code' : 'Text',
                content: '/tmp/my%20file.ts',
              },
            ],
          }}
          style={style}
          styles={buildStyles(style)}
          callbacks={{ onLinkPress: (event) => calls.push(event) }}
          capabilities={{ katex: null, enableTaskListItemToggle: true }}
        />
      );
    });
    act(() => {
      tree.container
        .queryAll((instance) => instance.type === 'a')[0]!
        .props.onClick({ preventDefault() {} });
    });
    expect(calls).toEqual([{ url: '/tmp/my%20file.ts', sourceType }]);
    act(() => tree.unmount());
  }
);

it('parses newly mounted text synchronously after shared WASM initialization', async () => {
  const { parseMarkdown, parseMarkdownSync } =
    await import('../src/web/parseMarkdown');
  await parseMarkdown('Initialize', { latexMath: false });
  const ast = parseMarkdownSync('Visible on first render', {
    latexMath: false,
  });
  expect(ast).not.toBeNull();
  expect(ast).not.toBeInstanceOf(Promise);
  expect(JSON.stringify(ast)).toContain('Visible on first render');
});
