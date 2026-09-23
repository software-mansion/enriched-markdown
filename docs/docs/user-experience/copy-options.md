---
sidebar_label: Copy options
sidebar_position: 3
---

# Copy options

When text is selected, the library provides enhanced copy functionality through the native context menu on both platforms.

## Smart copy

The default **Copy** action copies the selection with rich-formatting support, so receiving apps pick the richest format they understand:

- **iOS** copies several formats simultaneously - Plain Text, Markdown (original syntax preserved), HTML, RTF (for apps like Notes and Pages), and RTFD (RTF with embedded images).
- **Android** copies both Plain Text and HTML, so rich-text targets (Gmail, Google Docs) keep the formatting.

## Copy as Markdown

A dedicated **Copy as Markdown** action copies only the Markdown source text - useful when you want to preserve the original syntax rather than rich formatting.

## Copy image URL

When the selection contains images, a **Copy Image URL** action copies the image's source URL. On Android, if multiple images are selected, all URLs are copied (one per line).

## Controlling the built-in menu

Use `selectionMenuConfig` to hide built-in selection-menu actions while keeping the native menu (and any custom items) intact. Each item takes `{ enabled }` to toggle visibility. `enableBlockContextMenu={false}` disables the long-press popup on code blocks, tables, and block math, leaving the code-block header copy button, accessibility copy action, and system text-selection menu unchanged.

<CodeTabs groupId="platform">
<Tab label="React Native">

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

The editor exposes the same `{ enabled, label }` shape, plus a built-in **Format** submenu controlled by `formatMenuConfig`:

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

</Tab>
<Tab label="iOS">

The standalone iOS SDK takes one config value, and each item is a plain `Bool`:

```swift
EnrichedMarkdownText(content)
  .markdownSelectionMenu(
    MarkdownSelectionMenuConfig(copyAsMarkdown: false, copyImageUrl: false)
  )
```

The system's own items - Copy, Look Up, Translate, Share - are untouched either way. There is no `enableBlockContextMenu` equivalent: the long-press menu on a table (Copy / Copy as Markdown) is always available. See [`.markdownSelectionMenu`](/ios/api-reference/enriched-markdown-text#markdownselectionmenu).

</Tab>
<Tab label="Android">

**Copy as Markdown** and **Copy Image URL** are added to the selection menu by default and behave as described above - but they are not configurable yet. The underlying view takes the same three options; the Compose API does not surface them, so there is no way to hide or relabel an item from `EnrichedMarkdownText`. See the [roadmap](/misc/roadmap#the-compose-api-surface).

</Tab>
</CodeTabs>

## Localizing labels

The built-in copy actions are English by default (**Copy**, **Copy as Markdown**, **Copy Image URL**). Set a `label` on each `selectionMenuConfig` item to translate it - typically wired to your i18n library. `copyImageUrl` also takes `pluralLabels` for when several images are selected.

<CodeTabs groupId="platform">
<Tab label="React Native">

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

</Tab>
<Tab label="iOS">

The standalone iOS SDK exposes one label:

```swift
EnrichedMarkdownText(content)
  .markdownSelectionMenu(
    MarkdownSelectionMenuConfig(copyAsMarkdownLabel: t("copyAsMarkdown"))
  )
```

**Copy Image URL** is not relabelable - its title is built in English and already pluralized by count ("Copy Image URL", "Copy 3 Image URLs"). Neither is the **Select All** item the package supplies when the system omits it for non-editable text. System **Copy** is the platform's own item and is localized by iOS.

</Tab>
<Tab label="Android">

No equivalent yet. The view underneath accepts a Copy as Markdown label, but the Compose API does not pass one through, so every built-in item is English. See the [roadmap](/misc/roadmap#the-compose-api-surface).

</Tab>
</CodeTabs>

Notes:

- Any `label` left `undefined` keeps its English default, so you override only the strings you need.
- `pluralLabels` uses CLDR plural categories (`zero`, `one`, `two`, `few`, `many`, `other`); only `other` is required and the rest fall back to it. The `{count}` token is replaced by the number of selected images.
- Labels apply to the main selection menu and the table, math, and code-block copy menus. With `flavor="github"`, the code-block header's copy button reuses the copy label for assistive technologies.
- OS-provided actions (Look Up, Translate) and the system Cut / Paste / Select All items are localized by the platform and are not affected.

## Reference

<CodeTabs groupId="platform">
<Tab label="React Native">

- [`selectionMenuConfig`](/react-native/api-reference/enriched-markdown-text#selectionmenuconfig) - toggle and relabel built-in menu actions.
- [`onCopyPress`](/react-native/api-reference/enriched-markdown-text#oncopypress) - fires when code is copied from a fenced code block.
- Editor extras: `formatMenuConfig` and `selectionMenuConfig` on [`EnrichedMarkdownTextInput`](/react-native/api-reference/enriched-markdown-text-input).

</Tab>
<Tab label="iOS">

- [`.markdownSelectionMenu`](/ios/api-reference/enriched-markdown-text#markdownselectionmenu) - toggle Copy as Markdown and Copy Image URL, and relabel the former.
- [What the system Copy puts on the pasteboard](/ios/api-reference/enriched-markdown-text#copy-flavors) - the standalone SDK writes **plain text and HTML**; the RTF and RTFD flavors described above are the React Native package's.
- [Tables](/ios/api-reference/element-structure#tables) - the separate long-press menu on a table.

</Tab>
<Tab label="Android">

- [`selectable`](/android/api-reference/enriched-markdown-text#selectable) - turn selection on or off. Copy writes **plain text and HTML**; Copy as Markdown and Copy Image URL are present with their English defaults and are not yet configurable.

</Tab>
</CodeTabs>
