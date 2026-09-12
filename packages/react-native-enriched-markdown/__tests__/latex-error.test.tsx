import { act } from 'react';
import type { ReactElement } from 'react';
import { createRoot } from 'test-renderer';
import type { Root, TestInstance } from 'test-renderer';
import { EnrichedMarkdownText } from '../src/native/EnrichedMarkdownText';
import type { LatexErrorEvent } from '../src/types/events';

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

function fireLatexError(view: TestInstance, event: LatexErrorEvent) {
  act(() => {
    view.props.onLatexError({ nativeEvent: event });
  });
}

it('always wires a native onLatexError handler', () => {
  const nativeView = renderNative(<EnrichedMarkdownText markdown="$x$" />);
  expect(typeof nativeView.props.onLatexError).toBe('function');
});

it('maps the native latex error event to the public callback', () => {
  const onLatexError = jest.fn();
  const nativeView = renderNative(
    <EnrichedMarkdownText markdown="$\\foo$" onLatexError={onLatexError} />
  );

  fireLatexError(nativeView, {
    source: '\\foo',
    message: 'RaTeX parse error: unknown command \\foo',
    displayMode: false,
  });

  expect(onLatexError).toHaveBeenCalledWith({
    source: '\\foo',
    message: 'RaTeX parse error: unknown command \\foo',
    displayMode: false,
  });
});

it('normalizes an empty native message to undefined', () => {
  const onLatexError = jest.fn();
  const nativeView = renderNative(
    <EnrichedMarkdownText markdown="$$\\bar$$" onLatexError={onLatexError} />
  );

  fireLatexError(nativeView, {
    source: '\\bar',
    message: '',
    displayMode: true,
  });

  expect(onLatexError).toHaveBeenCalledWith({
    source: '\\bar',
    message: undefined,
    displayMode: true,
  });
});

it('does not throw when no onLatexError prop is provided', () => {
  const nativeView = renderNative(<EnrichedMarkdownText markdown="$x$" />);
  expect(() =>
    fireLatexError(nativeView, {
      source: 'x',
      message: 'boom',
      displayMode: false,
    })
  ).not.toThrow();
});
