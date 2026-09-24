import { act } from 'react';
import { createRoot } from 'test-renderer';
import { EnrichedMarkdownText } from '../src/native/EnrichedMarkdownText';
import type { LinkContextMenu } from '../src/types/MarkdownTextProps';

jest.mock('../src/EnrichedMarkdownNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownNativeComponent',
}));
jest.mock('../src/EnrichedMarkdownTextNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownTextNativeComponent',
}));

it.each(['commonmark', 'github'] as const)(
  'uses current %s callbacks and rejects stale actions after updates',
  (flavor) => {
    const root = createRoot({
      textComponentTypes: [
        'EnrichedMarkdownNativeComponent',
        'EnrichedMarkdownTextNativeComponent',
      ],
    });
    const nativeView = () => {
      const [view] = root.container.queryAll((instance) =>
        String(instance.type).startsWith('EnrichedMarkdown')
      );
      if (!view) throw new Error('Native markdown view was not rendered');
      return view;
    };
    const render = (menus?: Record<string, LinkContextMenu>) => {
      act(() =>
        root.render(
          <EnrichedMarkdownText
            markdown="[Notes](./notes.md)"
            flavor={flavor}
            linkContextMenus={menus}
          />
        )
      );
    };
    const first = jest.fn();
    const current = jest.fn();
    render({ './notes.md': { items: [{ text: 'Open', onPress: first }] } });
    const press = nativeView().props.onLinkContextMenuItemPress;
    const fire = () =>
      act(() =>
        press({ nativeEvent: { url: './notes.md', itemText: 'Open' } })
      );

    // Native can still hold an action from an already-presented menu.
    render({ './notes.md': { items: [{ text: 'Open', onPress: current }] } });
    fire();
    expect(current).toHaveBeenCalledWith({ url: './notes.md' });
    expect(first).not.toHaveBeenCalled();

    for (const flags of [{ disabled: true }, { visible: false }]) {
      render({
        './notes.md': { items: [{ text: 'Open', onPress: current, ...flags }] },
      });
      fire();
    }
    render({
      './notes.md': { items: [{ text: 'Different', onPress: current }] },
    });
    fire();
    render({});
    fire();
    render();
    fire();
    expect(current).toHaveBeenCalledTimes(1);
    expect(nativeView().props.linkContextMenus).toEqual([]);
    expect(nativeView().props.enableLinkPreview).toBe(true);
    act(() => root.unmount());
  }
);
