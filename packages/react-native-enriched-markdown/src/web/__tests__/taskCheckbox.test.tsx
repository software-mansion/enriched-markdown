/**
 * @jest-environment jsdom
 */
import { act } from 'react';
import { createRoot, type TestInstance } from 'test-renderer';
import { TextEncoder } from 'util';
import type { EnrichedMarkdownTextProps } from '../../types/MarkdownTextProps.web';
import {
  ENRM_CHECKMARK_COLOR_VAR,
  ENRM_TASK_CHECKBOX_CLASS,
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

async function renderCheckboxes(
  props: EnrichedMarkdownTextProps
): Promise<TestInstance[]> {
  const root = createRoot();
  await act(async () => {
    await root.render(<EnrichedMarkdownText {...props} />);
  });
  return root.container.queryAll((i) => i.type === 'input');
}

it('draws the checkbox in the taskList colors', async () => {
  const [todo, done] = await renderCheckboxes({
    markdown: '- [ ] todo\n- [x] done',
    markdownStyle: {
      taskList: {
        borderColor: 'rgb(1, 2, 3)',
        checkedColor: 'rgb(4, 5, 6)',
        checkmarkColor: 'var(--on-accent)',
      },
    },
  });

  expect(todo!.props.style).toMatchObject({
    borderColor: 'rgb(1, 2, 3)',
    backgroundColor: 'transparent',
    backgroundImage: 'none',
  });
  expect(done!.props.style).toMatchObject({
    borderColor: 'transparent',
    backgroundColor: 'rgb(4, 5, 6)',
    [ENRM_CHECKMARK_COLOR_VAR]: 'var(--on-accent)',
    printColorAdjust: 'exact',
    WebkitPrintColorAdjust: 'exact',
  });
  expect(done!.props.className).toBe(ENRM_TASK_CHECKBOX_CLASS);
});

it('keeps a read-only checkbox inert', async () => {
  const [done] = await renderCheckboxes({
    markdown: '- [x] done',
    enableTaskListItemToggle: false,
  });

  expect(done!.props.readOnly).toBe(true);
  expect(done!.props.style.pointerEvents).toBe('none');
});
