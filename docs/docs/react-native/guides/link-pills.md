---
sidebar_label: Link pills
sidebar_position: 1
---

import LivePreview from '@site/src/components/LivePreview';
import LinkPillsSrc from '!!raw-loader!@site/src/examples/react-native/guides/link-pills/LinkPills';
import PerLinkContentSrc from '!!raw-loader!@site/src/examples/react-native/guides/link-pills/PerLinkContent';

# Link pills

`EnrichedMarkdownText` can present a link as a **pill**: a rounded box with an optional icon and a label, drawn by the native text stack and wrapped as one unit. A file link becomes a chip with a file icon and a short name, a mention becomes an avatar with the user's name, and the Markdown underneath stays an ordinary link.

:::caution
Pills are drawn by the native text stack, so they render on **iOS and Android only**. The web build and macOS render the same links as ordinary links - with the variant's colors and font - and ignore everything on this page. See [Web support](/react-native/guides/web-support#ignored-style-keys) and [macOS support](/react-native/guides/macos).
:::

## Two halves: presentation and content

A pill is configured in two places, on purpose:

- **Presentation** lives in [`markdownStyle.linkVariants[pattern].pill`](/react-native/api-reference/style-properties#pill): which links are pills, their colors and geometry, and optionally a label and icon shared by every link the pattern matches.
- **Per-link content** lives in the [`linkPillContent`](/react-native/api-reference/enriched-markdown-text#linkpillcontent) prop: a label, icon and tint for one exact URL.

This split keeps `markdownStyle` a stable constant while the content map changes as links appear, which is what keeps the re-renders cheap.

## Enabling pills

A variant turns its links into pills through its `pill` key. `pill: true` gives the default look; an object overrides it. The variant's `color`, `underline`, `backgroundColor` and `fontFamily` still apply, so a pill is styled the way its links already were. Every field of the object, with its default, is listed under [Link-specific style properties](/react-native/api-reference/style-properties#pill).

<LivePreview src={LinkPillsSrc} unavailable unavailableReason={<>iOS and Android only - pills are drawn by the native text stack.</>} />

## Per-link content

`linkPillContent` maps an exact link URL to `{ label?, iconUri?, iconTintColor? }`. It only affects links whose variant enables `pill`. For both label and icon the order is: the `linkPillContent` entry, then the variant's `pill.label` / `pill.iconUri`, then the link's own text (and no icon).

<LivePreview src={PerLinkContentSrc} unavailable unavailableReason={<>iOS and Android only - pills are drawn by the native text stack.</>} />

The variant's `pill.iconTintColor` tints the variant's own icon only. An icon set per link, such as an avatar, keeps its colors unless its entry has an `iconTintColor` of its own. An entry with only `iconTintColor` recolors the variant's icon for that one link.

Lookup is by exact URL, so it stays cheap with hundreds of links, and changing the map re-renders without touching `markdownStyle`. Keep the object reference stable between renders when its content has not changed.

## Line height {#line-height}

A pill is as tall as its font's line plus `paddingVertical` and `borderWidth` on both sides. A line grows to fit a pill, but only to the pill's own height, so pills on consecutive lines end up with no space between them when the line height leaves no room - touching on iOS, a hairline apart on Android, where the line box is measured in whole pixels. `pill.lineHeight` is for that case: a paragraph, list item, heading or quote that holds a pill gets lines at least that tall, on every line, so its spacing stays even. It only ever raises the block's own `lineHeight`; it does not size the pill, and blocks without pills are unaffected.

For text that [streams in](/rich-text-formatting/markdown-streaming), set the block's own `lineHeight` to that value instead. With `pill.lineHeight` a paragraph's line height depends on whether it holds a pill, so while streaming it changes the moment a link completes and becomes one, and the text around it moves. A block `lineHeight` is the same before and after, so nothing moves.

## Behavior

- The label uses the font of the surrounding text, including bold and italic applied around the link. Long labels truncate at the tail; the pill never grows past the available text width.
- The label is presentation only. Plain copy, [Copy as Markdown](/user-experience/copy-options), HTML and RTF export, and the iOS system actions (Look Up, Translate, Share) receive the original link text. [`onLinkPress`](/react-native/api-reference/enriched-markdown-text#onlinkpress) and [`onLinkLongPress`](/react-native/api-reference/enriched-markdown-text#onlinklongpress) receive the original URL.
- The [accessible name](/user-experience/accessibility) is the visible label, followed by the original link text when they differ.
- Pills work everywhere links render, including GitHub-flavor table cells and blockquotes.
- Links whose text contains an image, inline math, a hard line break or a spoiler stay ordinary links.
- A pill inside an unrevealed spoiler is hidden with the rest of the spoiler.
- A long-pressed pill can open a [link menu](/react-native/guides/link-menus) on iOS 17+; the menu is titled with the pill's label.

## Icon sources {#icon-sources}

Both `pill.iconUri` and a `linkPillContent` entry's `iconUri` take the same sources. Icons are drawn at the label's font size.

| Source                                                                                | iOS | Android |
| ------------------------------------------------------------------------------------- | --- | ------- |
| File path, `file://` URI, bundled asset name                                          | Yes | Yes     |
| `http://`, `https://` (including `Image.resolveAssetSource(require(...)).uri` in dev) | Yes | Yes     |
| `data:` (base64)                                                                      | Yes | Yes     |
| Drawable/raw resource name, `asset://`, `res://`, `content://`                        | No  | Yes     |

Local files show on the first layout. Remote icons load in the background through the same pipeline as Markdown images, using [`imageRequestHeaders`](/react-native/api-reference/enriched-markdown-text#imagerequestheaders), and the pill keeps room for them while they load. A source that fails to load gives that room back, so the pill shrinks to its label, and is retried after 30 seconds.

## Reference

- [Link-specific style properties](/react-native/api-reference/style-properties#pill) - `linkVariants` and every field of the `pill` key.
- [`linkPillContent`](/react-native/api-reference/enriched-markdown-text#linkpillcontent) - the per-link content prop.
- [Mentions](/rich-text-formatting/mentions) - the mention links that pills are most often used for.
- [Link menus](/react-native/guides/link-menus) - long-press menus for links, which pick up a pill's label as their title.
