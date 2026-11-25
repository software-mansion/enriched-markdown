/**
 * @jest-environment jsdom
 */
import { act } from 'react';
import { createRoot, type Root, type TestInstance } from 'test-renderer';
import { TextEncoder } from 'util';
import type { EnrichedMarkdownTextProps } from '../../types/MarkdownTextProps.web';
import { loadParser } from '../parseMarkdown';

jest.mock('react-native', () => ({
  Platform: { OS: 'web' },
  processColor: (color: unknown) => color,
}));

globalThis.TextEncoder ??= TextEncoder as typeof globalThis.TextEncoder;
const { EnrichedMarkdownText } =
  require('../EnrichedMarkdownText') as typeof import('../EnrichedMarkdownText');

beforeAll(() => loadParser());

async function render(props: EnrichedMarkdownTextProps): Promise<Root> {
  const root = createRoot();
  await act(async () => {
    await root.render(<EnrichedMarkdownText {...props} />);
  });
  return root;
}

function find(root: Root, type: string): TestInstance[] {
  return root.container.queryAll((instance) => instance.type === type);
}

function marker(item: TestInstance): TestInstance {
  return (item.children[0] as TestInstance).children[0] as TestInstance;
}

function text(instance: TestInstance): string {
  return instance.children
    .map((child) => (typeof child === 'string' ? child : text(child)))
    .join('');
}

it('draws bullets in bulletColor and bulletSize, shaped by depth', async () => {
  const root = await render({
    markdown: '- a\n  - b\n    - c',
    markdownStyle: { list: { bulletColor: 'rgb(1, 2, 3)', bulletSize: 10 } },
  });

  const [disc, ring, square] = find(root, 'li').map(marker);
  expect(disc!.props.style).toMatchObject({
    width: 10,
    backgroundColor: 'rgb(1, 2, 3)',
    borderRadius: '50%',
  });
  expect(ring!.props.style.border).toBe('1.5px solid rgb(1, 2, 3)');
  expect(square!.props.style.borderRadius).toBe(0);
});

it('numbers an ordered list from its start in the marker style', async () => {
  const root = await render({
    markdown: '3. a\n4. b',
    markdownStyle: {
      list: { markerColor: 'rgb(4, 5, 6)', markerFontWeight: '700' },
    },
  });

  const numbers = find(root, 'li').map(marker);
  expect(numbers.map(text)).toEqual(['3.99.', '4.99.']);
  expect(numbers[0]!.props.style).toMatchObject({
    color: 'rgb(4, 5, 6)',
    fontWeight: '700',
  });

  const invalid = await render({
    markdown: '1. a',
    markdownStyle: { list: { markerFontWeight: 'heavy' } },
  });
  expect(
    marker(find(invalid, 'li')[0]!).props.style.fontWeight
  ).toBeUndefined();
});

it('starts the text past the marker column and the gap', async () => {
  const defaults = await render({ markdown: '- a\n  - b' });
  const [item, nested] = find(defaults, 'li');
  expect(item!.props.style.marginInlineStart).toBe(15);
  expect(nested!.parent!.props.style.marginInlineStart).toBe(9);

  const custom = await render({
    markdown: '- a',
    markdownStyle: { list: { markerMinWidth: 40, gapWidth: 20 } },
  });
  const [customItem] = find(custom, 'li');
  expect(customItem!.props.style.marginInlineStart).toBe(60);
  expect((customItem!.children[0] as TestInstance).props.style.width).toBe(40);
});

it('keeps lists native and hides only their own markers', async () => {
  const root = await render({ markdown: '- a' });

  const [list] = find(root, 'ul');
  expect(list!.props['data-enrm-list']).toBe(true);
  const css = document.getElementById('enrm-list-markers')!.textContent;
  expect(css).toContain('[data-enrm-list] > li::marker');
  expect(css).toContain('@media (forced-colors: active)');
});

it('lines the marker up with the first line of a leading code block', async () => {
  const root = await render({
    markdown: '1. ```\n   code\n   ```',
    markdownStyle: { codeBlock: { marginTop: 16 } },
  });

  const [item] = find(root, 'li');
  expect((item!.children[0] as TestInstance).props.style.top).toBe(15);
});

it('keeps a leading nested list clear of the number', async () => {
  const root = await render({ markdown: '1. - a\n2. b\n   - c' });

  const [leading, following] = find(root, 'ul');
  expect(leading!.props.style.marginInlineStart).toBe(0);
  expect(following!.props.style.marginInlineStart).toBe(-12);
});

it('starts later paragraphs of an item on their own line', async () => {
  const root = await render({ markdown: '- First.\n\n  Second.' });

  const [item] = find(root, 'li');
  const content = item!.children[1] as TestInstance;
  const [first, second] = content.children as TestInstance[];
  expect(first!.props.style).toBeUndefined();
  expect(second!.props.style).toEqual({ display: 'block' });
});
