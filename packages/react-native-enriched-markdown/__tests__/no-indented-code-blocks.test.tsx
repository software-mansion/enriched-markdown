import { act } from 'react';
import { createRoot } from 'test-renderer';
import { EnrichedMarkdownText } from '../src/native/EnrichedMarkdownText';

jest.mock('../src/EnrichedMarkdownNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownNativeComponent',
}));
jest.mock('../src/EnrichedMarkdownTextNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownTextNativeComponent',
}));

it.each(['commonmark', 'github'] as const)(
  'normalizes and updates noIndentedCodeBlocks for %s without remounting',
  (flavor) => {
    const root = createRoot({
      textComponentTypes: [
        'EnrichedMarkdownNativeComponent',
        'EnrichedMarkdownTextNativeComponent',
      ],
    });
    let mountedView: unknown;
    for (const enabled of [undefined, false, true, false, undefined]) {
      act(() =>
        root.render(
          <EnrichedMarkdownText
            markdown="    **Indented prose**"
            flavor={flavor}
            md4cFlags={
              enabled === undefined
                ? undefined
                : { noIndentedCodeBlocks: enabled }
            }
          />
        )
      );
      const [view] = root.container.queryAll((instance) =>
        String(instance.type).startsWith('EnrichedMarkdown')
      );
      expect(view).toBeDefined();
      if (mountedView) expect(view).toBe(mountedView);
      mountedView = view;
      expect(view!.props.md4cFlags.noIndentedCodeBlocks).toBe(enabled ?? false);
      expect(view!.props.markdown).toBe('    **Indented prose**');
    }
    act(() => root.unmount());
  }
);
