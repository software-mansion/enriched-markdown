import { act } from 'react';
import type { ReactElement } from 'react';
import { createRoot } from 'test-renderer';
import type { Root, TestInstance } from 'test-renderer';
import { EnrichedMarkdownText } from '../src/native/EnrichedMarkdownText';

jest.mock('../src/EnrichedMarkdownNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownNativeComponent',
}));

jest.mock('../src/EnrichedMarkdownTextNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownTextNativeComponent',
}));

function renderNative(element: ReactElement): TestInstance {
  const root: Root = createRoot({
    textComponentTypes: [
      'EnrichedMarkdownNativeComponent',
      'EnrichedMarkdownTextNativeComponent',
    ],
  });
  act(() => root.render(element));

  const [nativeView] = root.container.queryAll((instance) =>
    String(instance.type).startsWith('EnrichedMarkdown')
  );
  if (!nativeView) throw new Error('Native markdown view was not rendered');
  return nativeView;
}

it('enables block context menus by default as a top-level native prop', () => {
  const nativeView = renderNative(
    <EnrichedMarkdownText markdown="```text\nhello\n```" flavor="github" />
  );

  expect(nativeView.props.enableBlockContextMenu).toBe(true);
  expect(nativeView.props.selectionMenuConfig).not.toHaveProperty(
    'blockContextMenu'
  );
});

it('forwards a disabled block context menu to native', () => {
  const nativeView = renderNative(
    <EnrichedMarkdownText
      markdown="```text\nhello\n```"
      flavor="github"
      enableBlockContextMenu={false}
    />
  );

  expect(nativeView.props.enableBlockContextMenu).toBe(false);
});
