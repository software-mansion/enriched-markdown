/**
 * @jest-environment jsdom
 */
import { act } from 'react';
import { createRoot, type Root, type TestInstance } from 'test-renderer';
import { TextEncoder } from 'util';
import type { EnrichedMarkdownTextProps } from '../../types/MarkdownTextProps.web';
import {
  ENRM_BULLET_COLOR_VAR,
  ENRM_MARKER_COLOR_VAR,
  ENRM_MARKER_WEIGHT_VAR,
  ENRM_TEXT_CLASS,
} from '../globalStyles';
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

it('passes the marker style to each list', async () => {
  const root = await render({
    markdown: '- bullet\n\n1. number',
    markdownStyle: {
      list: {
        bulletColor: 'rgb(1, 2, 3)',
        markerColor: 'rgb(4, 5, 6)',
        markerFontWeight: '700',
      },
    },
  });

  const markerStyle = {
    [ENRM_BULLET_COLOR_VAR]: 'rgb(1, 2, 3)',
    [ENRM_MARKER_COLOR_VAR]: 'rgb(4, 5, 6)',
    [ENRM_MARKER_WEIGHT_VAR]: '700',
  };
  const [ul] = find(root, 'ul');
  const [ol] = find(root, 'ol');
  expect(ul!.props.style).toMatchObject(markerStyle);
  expect(ol!.props.style).toMatchObject(markerStyle);
});

it('keeps the class the marker rule needs next to a custom className', async () => {
  const root = await render({ markdown: '- bullet', className: 'article' });

  const [wrapper] = find(root, 'div');
  expect(wrapper!.props.className).toBe(`${ENRM_TEXT_CLASS} article`);
});
