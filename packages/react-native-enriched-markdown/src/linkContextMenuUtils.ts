import type { LinkContextMenu } from './types/MarkdownTextProps';
import type { LinkContextMenuConfig } from './types/events';

export function normalizeLinkContextMenus(
  menus: Record<string, LinkContextMenu> | undefined
): LinkContextMenuConfig[] {
  return Object.entries(menus ?? {}).flatMap(([url, menu]) => {
    const items = menu.items
      .filter((item) => item.visible !== false)
      .map((item) => ({
        text: item.text,
        icon: item.icon ?? '',
        disabled: item.disabled ?? false,
        destructive: item.destructive ?? false,
      }));
    return items.length ? [{ url, title: menu.title ?? '', items }] : [];
  });
}

export function dispatchLinkContextMenuItem(
  menus: Record<string, LinkContextMenu> | undefined,
  url: string,
  itemText: string
) {
  if (!menus || !Object.prototype.hasOwnProperty.call(menus, url)) return;
  const item = menus[url]?.items.find(
    (candidate) => candidate.text === itemText
  );
  if (item && item.visible !== false && !item.disabled) item.onPress({ url });
}
