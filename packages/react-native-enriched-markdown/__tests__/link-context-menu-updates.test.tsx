import { act } from 'react';
import { createRoot } from 'test-renderer';
import { EnrichedMarkdownText } from '../src/native/EnrichedMarkdownText';
import type { LinkContextMenuItem } from '../src/types/MarkdownTextProps';

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
    const render = (menus?: Record<string, LinkContextMenuItem[]>) => {
      act(() =>
        root.render(
          <EnrichedMarkdownText
            markdown="[Notes](./notes.md)"
            flavor={flavor}
            linkContextMenuItems={menus}
          />
        )
      );
    };
    const first = jest.fn();
    const current = jest.fn();
    render({ notes: [{ text: 'Open', onPress: first }] });
    const sentFirst = nativeView().props.linkContextMenuItems;
    const press = nativeView().props.onLinkContextMenuItemPress;
    const fire = () =>
      act(() =>
        press({
          nativeEvent: {
            url: './notes.md',
            pattern: 'notes',
            itemText: 'Open',
          },
        })
      );

    // Native can still hold an action from an already-presented menu.
    render({ notes: [{ text: 'Open', onPress: current }] });
    // Only the callback changed, so native is not sent the menus again.
    expect(nativeView().props.linkContextMenuItems).toBe(sentFirst);
    fire();
    expect(current).toHaveBeenCalledWith({ url: './notes.md' });
    expect(first).not.toHaveBeenCalled();

    for (const flags of [{ disabled: true }, { visible: false }]) {
      render({ notes: [{ text: 'Open', onPress: current, ...flags }] });
      fire();
    }
    render({ notes: [{ text: 'Different', onPress: current }] });
    fire();
    render({});
    fire();
    render();
    fire();
    expect(current).toHaveBeenCalledTimes(1);
    expect(nativeView().props.linkContextMenuItems).toEqual([]);
    expect(nativeView().props.enableLinkPreview).toBe(true);
    act(() => root.unmount());
  }
);
