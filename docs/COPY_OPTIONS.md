# Copy Options

When text is selected, `react-native-enriched-markdown` provides enhanced copy functionality through the context menu on both platforms.

## Smart Copy

The default **Copy** action copies the selected text with rich formatting support:

### iOS

Copies in multiple formats simultaneously — receiving apps pick the richest format they support:

| Format | Description |
|--------|-------------|
| **Plain Text** | Basic text without formatting |
| **Markdown** | Original Markdown syntax preserved |
| **HTML** | Rich HTML representation |
| **RTF** | Rich Text Format for apps like Notes, Pages |
| **RTFD** | RTF with embedded images |

### Android

Copies as both **Plain Text** and **HTML** — apps that support rich text (like Gmail, Google Docs) will preserve formatting.

## Copy as Markdown

A dedicated **Copy as Markdown** option is available in the context menu on both platforms. This copies only the Markdown source text, useful when you want to preserve the original syntax.

## Copy Image URL

When selecting text that contains images, a **Copy Image URL** option appears to copy the image's source URL. On Android, if multiple images are selected, all URLs are copied (one per line).

## Controlling Built-in Menu Items

Use `selectionMenuConfig` to hide built-in selection menu actions while keeping the native menu and any `contextMenuItems` intact. Each item takes an object — `{ enabled }` toggles visibility:

```tsx
<EnrichedMarkdownText
  markdown={content}
  selectionMenuConfig={{
    copyAsMarkdown: { enabled: false },
    copyImageUrl: { enabled: false },
  }}
/>
```

`EnrichedMarkdownTextInput` supports the same `{ enabled, label }` shape. In addition to `copyAsMarkdown`, the input's `selectionMenuConfig` exposes the built-in **Format** submenu, and `formatMenuConfig` controls the items inside it:

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

## Localizing Menu Labels

The built-in copy actions are shown in English by default (**Copy**, **Copy as
Markdown**, **Copy Image URL**). Set a `label` on each `selectionMenuConfig` item
to translate it so it matches the rest of your app's UI — typically wired to your
i18n library:

```tsx
<EnrichedMarkdownText
  markdown={content}
  selectionMenuConfig={{
    copy: { label: t('copy') }, // "Copia"
    copyAsMarkdown: { label: t('copyAsMarkdown') }, // "Copia come Markdown"
    copyImageUrl: {
      label: t('copyImageUrl'), // "Copia URL immagine" (single image)
      pluralLabels: {
        // Forms for multiple images, chosen with Intl.PluralRules.
        other: t('copyImageUrls'), // "Copia {count} URL immagine"
      },
    },
  }}
/>
```

Notes:

- Any `label` left `undefined` keeps its English default, so you can override
  only the strings you need.
- `pluralLabels` provides the forms used when several images are selected. The
  right form is picked at runtime from the number of selected images with
  `Intl.PluralRules` (resolved against the app's default locale), keyed by CLDR
  plural category (`zero`, `one`, `two`, `few`, `many`, `other`). Only `other` is
  required; any category left `undefined` falls back to it. The `{count}` token
  is replaced by the number of selected images.
- The labels apply to the main text selection menu as well as the table, math,
  and code block copy menus. With `flavor="github"`, the code block header's copy
  button also reuses the copy label for assistive technologies (the CommonMark
  flavor renders code inline with no header button): it is the button's
  contentDescription on Android, and on iOS it names the VoiceOver custom
  action that triggers the copy. To be notified when code is copied from a code
  block, use the [`onCopyPress`](./API_REFERENCE.md#oncopypress) callback.
- OS-provided actions (Look Up, Translate…) and the system **Cut / Paste /
  Select All** items are localized by the platform and are not affected by this
  config.

### Input (`EnrichedMarkdownTextInput`)

The input exposes the same `{ enabled, label }` shape on `selectionMenuConfig`
(for the **Format** submenu title and **Copy as Markdown** action) and on
`formatMenuConfig` (for each item inside the Format submenu — Bold, Italic,
Underline, Strikethrough, Spoiler, Link):

```tsx
<EnrichedMarkdownTextInput
  selectionMenuConfig={{
    format: { label: t('format') },
    copyAsMarkdown: { label: t('copyAsMarkdown') },
  }}
  formatMenuConfig={{
    bold: { label: t('bold') },
    italic: { label: t('italic') },
    underline: { label: t('underline') },
    strikethrough: { label: t('strikethrough') },
    spoiler: { label: t('spoiler') },
    link: { label: t('link') },
  }}
/>
```

> The simplest way to keep these in sync with the device language is to feed the
> same translation function you already use for the rest of your UI.
