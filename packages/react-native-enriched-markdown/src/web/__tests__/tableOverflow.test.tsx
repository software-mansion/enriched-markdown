/**
 * @jest-environment jsdom
 */
import { act } from 'react';
import { createRoot, type Root, type TestInstance } from 'test-renderer';
import { TextEncoder } from 'util';
import type { EnrichedMarkdownTextProps } from '../../types/MarkdownTextProps.web';
import { loadParser } from '../parseMarkdown';

globalThis.TextEncoder ??= TextEncoder as typeof globalThis.TextEncoder;
const { EnrichedMarkdownText } =
  require('../EnrichedMarkdownText') as typeof import('../EnrichedMarkdownText');

beforeAll(() => loadParser());

async function renderTable(
  markdownStyle?: EnrichedMarkdownTextProps['markdownStyle']
): Promise<{ scroller: TestInstance; frame: TestInstance }> {
  const root: Root = createRoot();
  await act(async () => {
    await root.render(
      <EnrichedMarkdownText
        markdown={'| A | B |\n| --- | --- |\n| 1 | 2 |'}
        markdownStyle={markdownStyle}
      />
    );
  });
  const [table] = root.container.queryAll((i) => i.type === 'table');
  const frame = table!.parent!;
  return { scroller: frame.parent!, frame };
}

it('lets the table scroll past the column by horizontalOverflow', async () => {
  const { scroller, frame } = await renderTable({
    table: { horizontalOverflow: 16, borderRadius: 8 },
  });

  expect(scroller.props.style).toMatchObject({
    overflowX: 'auto',
    marginInline: -16,
    paddingInline: 16,
  });
  expect(frame.props.style).toMatchObject({
    overflow: 'hidden',
    borderRadius: 8,
  });
});

it('keeps the table in the column by default', async () => {
  const { scroller } = await renderTable();

  expect(scroller.props.style.marginInline).toBeUndefined();
  expect(scroller.props.style.paddingInline).toBeUndefined();
});
