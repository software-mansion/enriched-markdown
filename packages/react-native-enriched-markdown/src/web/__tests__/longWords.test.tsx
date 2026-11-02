import { act } from 'react';
import { createRoot, type Root, type TestInstance } from 'test-renderer';
import { EnrichedMarkdownText } from '../EnrichedMarkdownText';
import type { EnrichedMarkdownTextProps } from '../../types/MarkdownTextProps.web';
import { ENRM_TEXT_CLASS } from '../globalStyles';

const LONG_URL = `https://example.com/${'a'.repeat(200)}`;

async function render(props: EnrichedMarkdownTextProps): Promise<Root> {
  const root = createRoot();
  await act(async () => {
    await root.render(
      <EnrichedMarkdownText md4cFlags={{ latexMath: false }} {...props} />
    );
  });
  // The parser loads asynchronously; nothing is rendered until it has.
  for (let i = 0; i < 30 && find(root, 'p').length === 0; i++) {
    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 100));
    });
  }
  return root;
}

function find(root: Root, type: string): TestInstance[] {
  return root.container.queryAll((instance) => instance.type === type);
}

function wrapper(root: Root): TestInstance {
  const [element] = root.container.queryAll(
    (instance) =>
      instance.type === 'div' && instance.props.className === ENRM_TEXT_CLASS
  );
  if (!element) throw new Error('EnrichedMarkdownText rendered no wrapper');
  return element;
}

it('breaks words longer than the line instead of overflowing', async () => {
  const root = await render({ markdown: `See ${LONG_URL}` });
  expect(find(root, 'p')).toHaveLength(1);
  expect(wrapper(root).props.style.overflowWrap).toBe('anywhere');
});

it('lets containerStyle override the word breaking', async () => {
  const root = await render({
    markdown: `See ${LONG_URL}`,
    containerStyle: { overflowWrap: 'normal' },
  });
  expect(wrapper(root).props.style.overflowWrap).toBe('normal');
});

it('keeps table columns from shrinking, so a wide table scrolls', async () => {
  const root = await render({
    markdown: `Table:\n\n| Link |\n| --- |\n| ${LONG_URL} |`,
  });
  const [table] = find(root, 'table');
  if (!table) throw new Error('No table was rendered');
  const scroller = table.parent!;
  expect(scroller.props.style.overflowX).toBe('auto');
  expect(scroller.props.style.overflowWrap).toBe('normal');
});
