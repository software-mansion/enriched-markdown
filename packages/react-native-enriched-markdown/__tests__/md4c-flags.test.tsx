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

it.each(['commonmark', 'github'] as const)(
  'forwards and updates strikethrough without changing the %s flavor',
  (flavor) => {
    const root = createRoot({
      textComponentTypes: [
        'EnrichedMarkdownNativeComponent',
        'EnrichedMarkdownTextNativeComponent',
      ],
    });
    for (const strikethrough of [undefined, false, true, false]) {
      act(() =>
        root.render(
          <EnrichedMarkdownText
            markdown="~~struck~~"
            flavor={flavor}
            numberOfLines={2}
            md4cFlags={{ strikethrough }}
          />
        )
      );
      const [view] = root.container.queryAll((instance) =>
        String(instance.type).startsWith('EnrichedMarkdown')
      );
      expect(view!.props.md4cFlags.strikethrough).toBe(
        flavor === 'commonmark' && (strikethrough ?? false)
      );
      expect(view!.props.isGFM).toBe(flavor === 'github');
      expect(view!.type).toBe(
        flavor === 'github'
          ? 'EnrichedMarkdownNativeComponent'
          : 'EnrichedMarkdownTextNativeComponent'
      );
      if (flavor === 'commonmark') expect(view!.props.numberOfLines).toBe(2);
    }
  }
);

it('keeps the md4cFlags prop stable when strikethrough toggles under github', () => {
  const root = createRoot({
    textComponentTypes: ['EnrichedMarkdownNativeComponent'],
  });
  const render = (strikethrough: boolean) => {
    act(() =>
      root.render(
        <EnrichedMarkdownText
          markdown="~~struck~~"
          flavor="github"
          md4cFlags={{ strikethrough }}
        />
      )
    );
    const [view] = root.container.queryAll(
      (instance) => instance.type === 'EnrichedMarkdownNativeComponent'
    );
    return view!.props.md4cFlags;
  };
  expect(render(true)).toBe(render(false));
});
