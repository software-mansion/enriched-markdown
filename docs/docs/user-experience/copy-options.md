---
sidebar_label: Copy options
sidebar_position: 3
---

# Copy options

When text is selected, the library provides enhanced copy functionality through the native context menu on iOS, macOS and Android.

:::note
None of this page applies to the React Native package on **web**. `selectionMenuConfig`, `contextMenuItems`, `enableBlockContextMenu` and `onCopyPress` are all stripped there, the web build never writes to the clipboard itself, and there is no code-block header or copy button. [`selectable`](/react-native/api-reference/enriched-markdown-text#selectable) is honored.
:::

## Smart copy

The default **Copy** action copies the selection with rich-formatting support, so receiving apps pick the richest format they understand. In the React Native package:

- **iOS** copies several formats simultaneously - Plain Text, Markdown (original syntax preserved, under the `net.daringfireball.markdown` type that lets a receiving app recognize it), HTML, RTF (for apps like Notes and Pages), and RTFD (RTF with embedded images).
- **Android** copies both Plain Text and HTML, so rich-text targets (Gmail, Google Docs) keep the formatting.

The standalone SDKs both write **Plain Text and HTML**: see what [iOS](/ios/api-reference/enriched-markdown-text#copy-flavors) and [Android](/android/api-reference/enriched-markdown-text#copying) put on the clipboard.

## Copy as Markdown

A dedicated **Copy as Markdown** action copies only the Markdown source text - useful when you want to preserve the original syntax rather than rich formatting. It writes **plain text only** on both platforms, with no Markdown pasteboard type attached, so a receiving app sees it as ordinary text that happens to contain Markdown syntax. It also does **not** fire the React Native package's [`onCopyPress`](/react-native/api-reference/enriched-markdown-text#oncopypress), nor the standalone iOS SDK's [`.onCodeBlockCopy`](/ios/api-reference/enriched-markdown-text#oncodeblockcopy).

## Copy image URL

When the selection contains images, a **Copy Image URL** action copies the image's source URL. If multiple images are selected, all URLs are copied, one per line, on both platforms.

Both platforms filter the selection to `http(s)` URLs, so local, bundled and `data:` images produce **no menu item at all**.

## Controlling the built-in menu

<CodeTabs groupId="platform">
<Tab label="React Native">

In the React Native package, use `selectionMenuConfig` to hide built-in selection-menu actions while keeping the native menu (and any custom items) intact. `copyAsMarkdown` and `copyImageUrl` take `{ enabled }` to toggle visibility; the system **Copy** item takes only `{ label }` and **cannot be hidden**, only relabeled. `enableBlockContextMenu={false}` disables the long-press popup on code blocks, tables, and block math, leaving the code-block header copy button, accessibility copy action, and system text-selection menu unchanged.

```tsx
<EnrichedMarkdownText
  markdown={content}
  enableBlockContextMenu={false}
  selectionMenuConfig={{
    copyAsMarkdown: { enabled: false },
    copyImageUrl: { enabled: false },
  }}
/>
```

The editor uses the same `{ enabled, label }` item shape but a **different key set** - only `format` and `copyAsMarkdown`, with no `copy`, no `copyImageUrl` and no `pluralLabels`. It adds a built-in **Format** submenu controlled by `formatMenuConfig`:

```tsx
<EnrichedMarkdownTextInput
  selectionMenuConfig={{
    format: { enabled: false },
    copyAsMarkdown: { enabled: false },
  }}
  formatMenuConfig={{
    spoiler: { enabled: false },
    link: { enabled: false },
  }}
/>
```

:::note
Selection cannot span two block segments under [`flavor="github"`](/react-native/guides/markdown-flavors), so a copy there is always scoped to a single block. Under `commonmark` the whole document is one text run and a selection can cover all of it.
:::

</Tab>
<Tab label="iOS">

The standalone iOS SDK takes one `MarkdownSelectionMenu` value through `.markdownSelectionMenu(_:)`: two `Bool`s and a label.

```swift
EnrichedMarkdownText(content)
  .markdownSelectionMenu(
    MarkdownSelectionMenu(copyAsMarkdown: false, copyImageURL: false)
  )
```

- `copyAsMarkdown` and `copyImageURL` toggle the two items the package adds; `copyAsMarkdownLabel` relabels the first (see [Localizing labels](#localizing-labels)).
- The system's own items - Copy, Look Up, Translate, Share - stay in the menu and cannot be hidden. The system **Copy** is overridden to write plain text plus HTML.
- There is no `enableBlockContextMenu` equivalent. The long-press menus on a table, a display-math block, and a code block rendered with [`.markdownCodeBlockLayout(.scrollable)`](/ios/api-reference/enriched-markdown-text#markdowncodeblocklayout) (**Copy** / **Copy as Markdown**) are always available, ignore `MarkdownSelectionMenu`, and their titles are English.
- [`.onCodeBlockCopy`](/ios/api-reference/enriched-markdown-text#oncodeblockcopy) reports code copied from a panel's button, its long-press **Copy**, or the VoiceOver "Copy code" action - never Copy as Markdown.

See [`.markdownSelectionMenu`](/ios/api-reference/enriched-markdown-text#markdownselectionmenu).

</Tab>
<Tab label="Android">

**Copy as Markdown** and **Copy Image URL** are added to the selection menu by default, and tables and display-math blocks offer a long-press menu (**Copy** / **Copy as Markdown**). None of it is configurable from Compose yet: the underlying view takes a `SelectionMenuConfig` with three fields - `copyAsMarkdown`, `copyImageUrl`, `copyAsMarkdownLabel` - which its table and math menus honour too, but the Compose `EnrichedMarkdownText` does not expose it, so Compose apps get the defaults. Code blocks have no copy action. See [`selectable`](/android/api-reference/enriched-markdown-text#selectable) and the [roadmap](/misc/roadmap).

</Tab>
</CodeTabs>

## Localizing labels

<CodeTabs groupId="platform">
<Tab label="React Native">

In the React Native package, the built-in copy actions are English by default (**Copy**, **Copy as Markdown**, **Copy Image URL**). Set a `label` on each `selectionMenuConfig` item to translate it - typically wired to your i18n library. `copyImageUrl` also takes `pluralLabels` for when several images are selected.

```tsx
<EnrichedMarkdownText
  markdown={content}
  selectionMenuConfig={{
    copy: { label: t('copy') },
    copyAsMarkdown: { label: t('copyAsMarkdown') },
    copyImageUrl: {
      label: t('copyImageUrl'), // single image
      pluralLabels: {
        // Chosen at runtime with Intl.PluralRules; {count} is the image count.
        other: t('copyImageUrls'),
      },
    },
  }}
/>
```

:::caution
The library **replaces the platform's own localized Copy item** with its own, titled from `copy.label` - and because a concrete English default is always resolved, it does so unconditionally. On a non-English device the menu therefore reads `"Copy"` in English until you relabel it. Set `copy.label` whenever you localize anything else here.
:::

Notes:

- Any `label` left `undefined` keeps its English default, so you override only the strings you need.
- `pluralLabels` uses CLDR plural categories (`zero`, `one`, `two`, `few`, `many`, `other`); only `other` is required and the rest fall back to it. The `{count}` token is replaced by the number of selected images. Three sharp edges:
  - **`Intl.PluralRules` is constructed with no locale**, so it follows the JS runtime's default. On an English device only `one` and `other` ever fire, even if you supply `few` and `many`.
  - Templates are precomputed for counts **0 to 100**; above that, `other` is used.
  - If `Intl.PluralRules` is missing or throws, `pluralLabels` is ignored entirely and the singular `label` is used.
- Labels apply to the main selection menu and the table, math, and code-block copy menus on both iOS and Android. With `flavor="github"`, the code-block header's copy button reuses the copy label for assistive technologies.
- OS-provided actions (Look Up, Translate) and the system Cut / Paste / Select All items are localized by the platform and are not affected.

</Tab>
<Tab label="iOS">

The standalone iOS SDK exposes one label, for the selection menu's **Copy as Markdown** item:

```swift
EnrichedMarkdownText(content)
  .markdownSelectionMenu(
    MarkdownSelectionMenu(copyAsMarkdownLabel: "Als Markdown kopieren")
  )
```

Everything else is fixed:

- **Copy Image URL** has a built-in English title, already pluralized by count ("Copy Image URL", "Copy 3 Image URLs").
- The **Select All** item the package supplies when the system omits it for non-editable text is English.
- The table, display-math, and code-block long-press menus are English, with no override.
- System **Copy** stays the platform's own item, localized by iOS.

</Tab>
<Tab label="Android">

Not localizable from Compose. The view underneath accepts a Copy as Markdown label (`SelectionMenuConfig.copyAsMarkdownLabel`), but the Compose `EnrichedMarkdownText` does not pass one through, so every item the library adds is English. See the [roadmap](/misc/roadmap).

</Tab>
</CodeTabs>

## Reference

<CodeTabs groupId="platform">
<Tab label="React Native">

- [`selectionMenuConfig`](/react-native/api-reference/enriched-markdown-text#selectionmenuconfig) - toggle and relabel built-in menu actions. Its exported type is **`TextSelectionMenuConfig`** (with `TextSelectionMenuPluralLabels`); the unprefixed names belong to the editor.
- [`contextMenuItems`](/react-native/api-reference/enriched-markdown-text#contextmenuitems) - add your own actions. Its exported type is **`TextContextMenuItem`**; bare `ContextMenuItem` at the package root is the **editor's** type, which carries an extra `styleState` field in its `onPress` payload.
- [`onCopyPress`](/react-native/api-reference/enriched-markdown-text#oncopypress) - fires when code is copied from a fenced code block, via the header button, the long-press Copy action, or the VoiceOver copy action. It only fires under `flavor="github"`, and never for Copy as Markdown. Payload: `{ code, language }`.
- [`enableBlockContextMenu`](/react-native/api-reference/enriched-markdown-text#enableblockcontextmenu) - turn the long-press block menu off.
- Editor extras: `formatMenuConfig` and `selectionMenuConfig` on [`EnrichedMarkdownTextInput`](/react-native/api-reference/enriched-markdown-text-input).

</Tab>
<Tab label="iOS">

- [`.markdownSelectionMenu`](/ios/api-reference/enriched-markdown-text#markdownselectionmenu) - toggle Copy as Markdown and Copy Image URL, and relabel the former.
- [What the system Copy puts on the pasteboard](/ios/api-reference/enriched-markdown-text#copy-flavors) - **plain text and HTML**.
- [Tables](/ios/api-reference/element-structure#tables) - the separate long-press menu on a table.
- [`.markdownCodeBlockLayout(.scrollable)`](/ios/api-reference/enriched-markdown-text#markdowncodeblocklayout) - code-block panels with a copy button and a long-press menu.
- [`.onCodeBlockCopy`](/ios/api-reference/enriched-markdown-text#oncodeblockcopy) - fires when code is copied.

</Tab>
<Tab label="Android">

- [`selectable`](/android/api-reference/enriched-markdown-text#selectable) - turn selection on or off. Copy writes **plain text and HTML**; Copy as Markdown and Copy Image URL are present with their English defaults and are not configurable from Compose.

</Tab>
</CodeTabs>
