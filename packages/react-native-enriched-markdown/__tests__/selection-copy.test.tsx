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

const nativeEvent = {
  text: '**bold**',
  format: 'markdown',
  selectionStart: 7,
  selectionEnd: 11,
};

it.each(['commonmark', 'github'] as const)(
  'maps the flat native event to the nested public shape with flavor="%s"',
  (flavor) => {
    const onSelectionCopy = jest.fn();
    const view = renderNative(
      <EnrichedMarkdownText
        flavor={flavor}
        markdown="some **bold** text"
        onSelectionCopy={onSelectionCopy}
      />
    );

    act(() => view.props.onSelectionCopy({ nativeEvent }));

    expect(onSelectionCopy).toHaveBeenCalledTimes(1);
    expect(onSelectionCopy).toHaveBeenCalledWith({
      text: '**bold**',
      format: 'markdown',
      selection: { start: 7, end: 11 },
    });
  }
);

it('does not throw when no onSelectionCopy prop is provided', () => {
  const view = renderNative(<EnrichedMarkdownText markdown="text" />);

  expect(() =>
    act(() => view.props.onSelectionCopy({ nativeEvent }))
  ).not.toThrow();
});
