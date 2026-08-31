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

it('defaults md4cFlags.preserveBlankLines to false on the native prop', () => {
  const nativeView = renderNative(
    <EnrichedMarkdownText markdown="one\n\n\n\ntwo" flavor="github" />
  );

  expect(nativeView.props.md4cFlags.preserveBlankLines).toBe(false);
});

it('forwards md4cFlags.preserveBlankLines to native when enabled', () => {
  const nativeView = renderNative(
    <EnrichedMarkdownText
      markdown="one\n\n\n\ntwo"
      flavor="github"
      md4cFlags={{ preserveBlankLines: true }}
    />
  );

  expect(nativeView.props.md4cFlags.preserveBlankLines).toBe(true);
});

it('disables GFM extensions for the commonmark flavor', () => {
  const nativeView = renderNative(
    <EnrichedMarkdownText
      markdown={'| Model | Speed |\n|---|---|\n| Claude | Fast |'}
      flavor="commonmark"
    />
  );

  expect(nativeView.props.isGFM).toBe(false);
  expect(nativeView.props.md4cFlags).not.toHaveProperty('tables');
});

it('enables GFM extensions for the github flavor', () => {
  const nativeView = renderNative(
    <EnrichedMarkdownText
      markdown={'| Model | Speed |\n|---|---|\n| Claude | Fast |'}
      flavor="github"
    />
  );

  expect(nativeView.props.isGFM).toBe(true);
  expect(nativeView.props.md4cFlags).not.toHaveProperty('tables');
});
