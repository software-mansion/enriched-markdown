import { act } from 'react';
import type { ReactElement } from 'react';
import { createRoot } from 'test-renderer';
import type { Root, TestInstance } from 'test-renderer';
import { EnrichedMarkdownText } from '../src/native/EnrichedMarkdownText';
import type {
  HighlightLayoutEvent,
  RenderedTextChangeEvent,
} from '../src/types/events';
import type { TextHighlight } from '../src/types/MarkdownTextProps';

jest.mock('../src/EnrichedMarkdownNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownNativeComponent',
}));

jest.mock('../src/EnrichedMarkdownTextNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownTextNativeComponent',
}));

function renderNative(element: ReactElement): {
  root: Root;
  view: () => TestInstance;
} {
  const root: Root = createRoot({
    textComponentTypes: [
      'EnrichedMarkdownNativeComponent',
      'EnrichedMarkdownTextNativeComponent',
    ],
  });
  act(() => root.render(element));
  const view = () => {
    const [nativeView] = root.container.queryAll((instance) =>
      String(instance.type).startsWith('EnrichedMarkdown')
    );
    if (!nativeView) throw new Error('Native markdown view was not rendered');
    return nativeView;
  };
  return { root, view };
}

it('sends highlights with colors as signed 32-bit ARGB', () => {
  const { view } = renderNative(
    <EnrichedMarkdownText
      markdown="Hello world"
      highlights={[
        { start: 0, end: 5, color: '#FF0000' },
        { start: 6, end: 11, color: 'rgba(0, 0, 255, 0.5)', borderRadius: 4 },
      ]}
    />
  );

  expect(view().props.highlights).toEqual([
    { start: 0, end: 5, color: -65536, borderRadius: 0, padding: 0 },
    {
      start: 6,
      end: 11,
      color: 0x800000ff - 0x100000000,
      borderRadius: 4,
      padding: 0,
    },
  ]);
});

it('drops a highlight whose color cannot be processed', () => {
  const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  const { view } = renderNative(
    <EnrichedMarkdownText
      markdown="Hello"
      highlights={[{ start: 0, end: 5, color: 'not-a-color' }]}
    />
  );

  expect(view().props.highlights).toEqual([]);
  warn.mockRestore();
});

it('keeps the native highlights when the same array renders again', () => {
  const highlights: TextHighlight[] = [{ start: 0, end: 1, color: 'red' }];
  const { root, view } = renderNative(
    <EnrichedMarkdownText markdown="a" highlights={highlights} />
  );
  const first = view().props.highlights;

  act(() =>
    root.render(<EnrichedMarkdownText markdown="a" highlights={highlights} />)
  );

  expect(view().props.highlights).toBe(first);
});

it('asks for the rendered text only when a listener is set', () => {
  const { root, view } = renderNative(
    <EnrichedMarkdownText markdown="a" flavor="github" />
  );
  expect(view().props.enableRenderedTextChange).toBe(false);

  act(() =>
    root.render(
      <EnrichedMarkdownText
        markdown="a"
        flavor="github"
        onRenderedTextChange={() => {}}
      />
    )
  );
  expect(view().props.enableRenderedTextChange).toBe(true);
});

it('maps the rendered text event to the public callback', () => {
  const onRenderedTextChange = jest.fn();
  const { view } = renderNative(
    <EnrichedMarkdownText
      markdown="a"
      flavor="github"
      onRenderedTextChange={onRenderedTextChange}
    />
  );
  const event: RenderedTextChangeEvent = {
    text: 'Title\nx = 1',
    blocks: [
      { start: 0, end: 5, kind: 'text' },
      { start: 6, end: 11, kind: 'code' },
    ],
  };

  act(() => view().props.onRenderedTextChange({ nativeEvent: event }));

  expect(onRenderedTextChange).toHaveBeenCalledWith(event);
});

it('maps the highlight layout event to the public callback', () => {
  const onHighlightLayout = jest.fn();
  const { view } = renderNative(
    <EnrichedMarkdownText markdown="a" onHighlightLayout={onHighlightLayout} />
  );
  const event: HighlightLayoutEvent = {
    highlights: [{ index: 1, x: 2, y: 3, width: 40, height: 20 }],
  };

  act(() => view().props.onHighlightLayout({ nativeEvent: event }));

  expect(onHighlightLayout).toHaveBeenCalledWith(event);
});
