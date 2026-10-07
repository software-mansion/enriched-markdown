---
sidebar_label: Link menus
sidebar_position: 4
---

import LivePreview from '@site/src/components/LivePreview';
import LinkMenusSrc from '!!raw-loader!@site/src/examples/react-native/user-experience/link-menus/LinkMenus';

# Link menus

A long press on a link can do three things in `EnrichedMarkdownText`, and which one happens depends on what you set and where the text runs:

| What the reader gets                | When                                                                                               | Where             |
| ----------------------------------- | -------------------------------------------------------------------------------------------------- | ----------------- |
| A menu with **your** items          | The link's URL matches a [`linkContextMenuItems`](/react-native/api-reference/enriched-markdown-text#linkcontextmenuitems) pattern with at least one visible item | iOS 17 and later  |
| Your [`onLinkLongPress`](/react-native/api-reference/enriched-markdown-text#onlinklongpress) handler | No menu applies and the handler is set                                        | iOS, Android, macOS; `contextmenu` on web |
| The system link preview             | Neither of the above, and [`enableLinkPreview`](/react-native/api-reference/enriched-markdown-text#enablelinkpreview) is on | iOS               |

This page is about the first row. The other two are plain props and are covered in the reference.

## Defining menus

`linkContextMenuItems` is a map from a URL pattern to the items shown for links that match it. Patterns are regexes tested against the link URL and matched like `markdownStyle.linkVariants`: the longest pattern that matches supplies the menu, so one entry covers every link of a kind, and a pattern anchored to a single URL gives that one link its own menu.

<LivePreview src={LinkMenusSrc} unavailable unavailableReason={<>iOS 17 and later only - the menu is the native link context menu.</>} />

Each item has:

- `text` - the label. It identifies the item, so it must be unique within one pattern.
- `onPress({ url })` - called with the link's original URL, including relative paths. The library does not navigate, copy or share for you; do that here.
- `icon` - an SF Symbol name, as in [`contextMenuItems`](/react-native/api-reference/enriched-markdown-text#contextmenuitems).
- `visible`, `disabled`, `destructive` - optional, all default to the obvious value. A hidden or disabled item is still part of the pattern's list, so toggling it does not change which pattern wins.

The menu holds only your items. Its title is the link's text, or the pill's label when the link is a [link pill](/rich-text-formatting/link-pills).

## Fallbacks

A link that matches no pattern, or whose pattern has no visible items, keeps its ordinary long-press behavior: `onLinkLongPress` if set, otherwise the system link preview on iOS.

Android, macOS and iOS below 17 ignore the prop entirely. Keep an `onLinkLongPress` handler next to your menus for those - as the example does - so the gesture still does something there.

## Changing menus while one is open

The prop can change while a menu is on screen, for example when a list of files refreshes. A press on an item that the current value no longer offers - removed, hidden or disabled - is ignored rather than acting on stale data.

## Relation to the other menus

`linkContextMenuItems` only touches the long press on a link. The rest of the menu surface is unchanged:

- The text-selection menu is controlled by [`contextMenuItems`](/react-native/api-reference/enriched-markdown-text#contextmenuitems) and [`selectionMenuConfig`](/react-native/api-reference/enriched-markdown-text#selectionmenuconfig).
- The block copy menus are controlled by [`enableBlockContextMenu`](/react-native/api-reference/enriched-markdown-text#enableblockcontextmenu); see [Copy options](/user-experience/copy-options).

Menus work in CommonMark text and in GitHub-flavor text segments, including blockquotes and table cells.

## Reference

- [`linkContextMenuItems`](/react-native/api-reference/enriched-markdown-text#linkcontextmenuitems) - the prop and the `LinkContextMenuItem` type.
- [`onLinkLongPress`](/react-native/api-reference/enriched-markdown-text#onlinklongpress) and [`enableLinkPreview`](/react-native/api-reference/enriched-markdown-text#enablelinkpreview) - the fallbacks.
- [Link pills](/rich-text-formatting/link-pills) - pills supply the menu title.
