import {
  dispatchLinkContextMenuItem,
  isLinkContextMenuItemsEqual,
  normalizeLinkContextMenuItems,
} from '../src/linkContextMenuUtils';
import type { LinkContextMenuItem } from '../src/types/MarkdownTextProps';

describe('link context menu items', () => {
  it('drops hidden items and empty patterns without serializing callbacks', () => {
    const callback = jest.fn();
    expect(
      normalizeLinkContextMenuItems({
        '^notes:': [
          { text: 'Open', icon: 'doc', onPress: callback },
          { text: 'Hidden', visible: false, onPress: callback },
          {
            text: 'Remove',
            disabled: true,
            destructive: true,
            onPress: callback,
          },
        ],
        '^empty:': [],
        '^hidden:': [{ text: 'Hidden', visible: false, onPress: callback }],
      })
    ).toEqual([
      {
        pattern: '^notes:',
        items: [
          { text: 'Open', icon: 'doc', disabled: false, destructive: false },
          { text: 'Remove', icon: '', disabled: true, destructive: true },
        ],
      },
    ]);
    expect(callback).not.toHaveBeenCalled();
    expect(normalizeLinkContextMenuItems(undefined)).toEqual([]);
  });

  it('orders patterns like linkVariants and ignores invalid ones', () => {
    const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
    const item = { text: 'Open', onPress: jest.fn() };
    const config = normalizeLinkContextMenuItems({
      '^https://': [item],
      '^https://example\\.com/files/': [item],
      '(': [item],
    });
    expect(config.map((entry) => entry.pattern)).toEqual([
      '^https://example\\.com/files/',
      '^https://',
    ]);
    expect(warn).toHaveBeenCalledWith(
      expect.stringContaining('linkContextMenuItems pattern "("')
    );
    warn.mockRestore();
  });

  it('produces JSON-serializable config without modifying public items', () => {
    const item = Object.freeze({ text: 'Open', onPress: jest.fn() });
    const menus = { '^notes:': [item] };
    const config = normalizeLinkContextMenuItems(menus);
    expect(JSON.parse(JSON.stringify(config))).toEqual(config);
    expect(menus['^notes:'][0]).toBe(item);
  });

  it('treats a change of callbacks alone as no change for native', () => {
    const make = (text: string, disabled = false) =>
      normalizeLinkContextMenuItems({
        '^notes:': [{ text, disabled, onPress: jest.fn() }],
      });
    expect(isLinkContextMenuItemsEqual(make('Open'), make('Open'))).toBe(true);
    expect(isLinkContextMenuItemsEqual(make('Open'), make('Copy'))).toBe(false);
    expect(isLinkContextMenuItemsEqual(make('Open'), make('Open', true))).toBe(
      false
    );
    expect(isLinkContextMenuItemsEqual(make('Open'), [])).toBe(false);
  });

  it('runs the item of the reported pattern with the pressed link', () => {
    const files = jest.fn();
    const web = jest.fn();
    const menus: Record<string, LinkContextMenuItem[]> = {
      '^https://example\\.com/files/': [{ text: 'Copy', onPress: files }],
      '^https://': [{ text: 'Copy', onPress: web }],
    };
    const url = 'https://example.com/files/資料 🚀.md';
    dispatchLinkContextMenuItem(
      menus,
      '^https://example\\.com/files/',
      'Copy',
      url
    );
    expect(files).toHaveBeenCalledWith({ url });
    expect(web).not.toHaveBeenCalled();
  });

  it('treats patterns as own entries even when they name object properties', () => {
    const callback = jest.fn();
    const menus = { ['__proto__']: [{ text: 'Open', onPress: callback }] };
    dispatchLinkContextMenuItem(menus, '__proto__', 'Open', 'x:1');
    expect(callback).toHaveBeenCalledWith({ url: 'x:1' });
    for (const pattern of ['__proto__', 'constructor', 'toString']) {
      expect(() =>
        dispatchLinkContextMenuItem({}, pattern, 'Open', 'x:1')
      ).not.toThrow();
    }
    expect(callback).toHaveBeenCalledTimes(1);
  });

  it('ignores removed, hidden, disabled and unknown items after a config update', () => {
    const callback = jest.fn();
    const menus: Record<string, LinkContextMenuItem[]> = {
      '^https://': [
        { text: 'Hidden', visible: false, onPress: callback },
        { text: 'Disabled', disabled: true, onPress: callback },
      ],
    };
    const url = 'https://example.com';
    for (const text of ['Hidden', 'Disabled', 'Removed'])
      dispatchLinkContextMenuItem(menus, '^https://', text, url);
    dispatchLinkContextMenuItem(menus, '^unknown:', 'Disabled', url);
    dispatchLinkContextMenuItem(undefined, '^https://', 'Removed', url);
    expect(callback).not.toHaveBeenCalled();
    menus['^https://'] = [{ text: 'Disabled', onPress: callback }];
    dispatchLinkContextMenuItem(menus, '^https://', 'Disabled', url);
    expect(callback).toHaveBeenCalledTimes(1);
  });
});
