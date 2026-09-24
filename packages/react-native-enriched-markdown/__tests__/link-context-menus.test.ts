import {
  normalizeLinkContextMenus,
  dispatchLinkContextMenuItem,
} from '../src/linkContextMenuUtils';
import type { LinkContextMenu } from '../src/types/MarkdownTextProps';

describe('per-link context menus', () => {
  it('omits hidden and empty menus without serializing callbacks', () => {
    const callback = jest.fn();
    expect(
      normalizeLinkContextMenus({
        './notes.md': {
          title: 'Notes',
          items: [
            { text: 'Open', icon: 'doc', onPress: callback },
            { text: 'Hidden', visible: false, onPress: callback },
            {
              text: 'Remove',
              disabled: true,
              destructive: true,
              onPress: callback,
            },
          ],
        },
        './empty.md': { items: [] },
        './hidden.md': {
          items: [{ text: 'Hidden', visible: false, onPress: callback }],
        },
      })
    ).toEqual([
      {
        url: './notes.md',
        title: 'Notes',
        items: [
          { text: 'Open', icon: 'doc', disabled: false, destructive: false },
          { text: 'Remove', icon: '', disabled: true, destructive: true },
        ],
      },
    ]);
    expect(callback).not.toHaveBeenCalled();
    expect(normalizeLinkContextMenus(undefined)).toEqual([]);
  });

  it('keeps identical labels scoped to the original URL, including relative and unicode URLs', () => {
    const first = jest.fn();
    const second = jest.fn();
    const menus: Record<string, LinkContextMenu> = {
      './first.md': { items: [{ text: 'Copy', onPress: first }] },
      './資料 🚀.md': { items: [{ text: 'Copy', onPress: second }] },
    };
    dispatchLinkContextMenuItem(menus, './資料 🚀.md', 'Copy');
    expect(second).toHaveBeenCalledWith({ url: './資料 🚀.md' });
    expect(first).not.toHaveBeenCalled();
  });

  it('produces JSON-serializable config without modifying public items', () => {
    const item = Object.freeze({ text: 'Open', onPress: jest.fn() });
    const menus = { './notes.md': { items: [item] } };
    const config = normalizeLinkContextMenus(menus);
    expect(JSON.parse(JSON.stringify(config))).toEqual(config);
    expect(config).toEqual([
      {
        url: './notes.md',
        title: '',
        items: [
          { text: 'Open', icon: '', disabled: false, destructive: false },
        ],
      },
    ]);
    expect(menus['./notes.md'].items[0]).toBe(item);
  });

  it('treats URL keys as own entries even when they match object properties', () => {
    const callback = jest.fn();
    const menus = {
      ['__proto__']: { items: [{ text: 'Open', onPress: callback }] },
    };
    dispatchLinkContextMenuItem(menus, '__proto__', 'Open');
    expect(callback).toHaveBeenCalledWith({ url: '__proto__' });
    for (const url of ['__proto__', 'constructor', 'toString']) {
      expect(() => dispatchLinkContextMenuItem({}, url, 'Open')).not.toThrow();
    }
    expect(callback).toHaveBeenCalledTimes(1);
  });

  it('rejects removed, hidden, disabled and unknown actions after a configuration update', () => {
    const callback = jest.fn();
    const menus: Record<string, LinkContextMenu> = {
      'https://example.com': {
        items: [
          { text: 'Hidden', visible: false, onPress: callback },
          { text: 'Disabled', disabled: true, onPress: callback },
        ],
      },
    };
    for (const action of ['Hidden', 'Disabled', 'Removed'])
      dispatchLinkContextMenuItem(menus, 'https://example.com', action);
    dispatchLinkContextMenuItem(menus, 'https://unknown.com', 'Disabled');
    dispatchLinkContextMenuItem(undefined, 'https://example.com', 'Removed');
    expect(callback).not.toHaveBeenCalled();
    menus['https://example.com'] = {
      items: [{ text: 'Disabled', onPress: callback }],
    };
    dispatchLinkContextMenuItem(menus, 'https://example.com', 'Disabled');
    expect(callback).toHaveBeenCalledTimes(1);
  });
});
