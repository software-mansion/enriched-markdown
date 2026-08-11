# Web Support

`EnrichedMarkdownText` runs on web using [`react-native-web`](https://necolas.github.io/react-native-web/) for the React Native primitives and [md4c](https://github.com/mity/md4c) compiled to WebAssembly for parsing. The WASM binary is bundled in the npm package — no build step is required by consumers.

The web renderer uses semantic HTML elements (`<p>`, `<h1>`–`<h6>`, `<blockquote>`, `<ul>`, `<ol>`, `<table>`, etc.) for improved accessibility.

## Supported features

All core `EnrichedMarkdownText` features are supported on web, including:

- Full GFM: tables (with horizontal scroll), task lists (with checkbox interaction), strikethrough, links, images (block and inline), code blocks, LaTeX math (block and inline)
- All `markdownStyle` customisation options
- `onLinkPress`, `onLinkLongPress` (mapped to `contextmenu` event), `onTaskListItemPress` callbacks
- `enableTaskListItemToggle` — set to `false` to render task list checkboxes read-only (the click is fully inert: no toggle, no `onTaskListItemPress`). The checkbox keeps its normal appearance, marked `readOnly` / `aria-disabled` and pointer-inert rather than `disabled`, matching iOS and Android
- `allowTrailingMargin`, `containerStyle`, `selectable`, `selectionColor`, `md4cFlags` (`underline`, `superscript`, `subscript`, `latexMath`, `highlight`, `hardSoftBreaks`)
- RTL support via the `dir` prop (CSS logical properties automatically flip blockquote borders, list indentation, etc.)

### Accessibility

- Semantic HTML elements for all markdown structures
- Images: `alt` text falls back to `title`, then URL filename, then `"Image"`
- Code blocks: `aria-label` with language when available (e.g. `"Code block: python"`)
- Math (KaTeX fallback): `role="math"` and `aria-label` with the expression content
- Task list checkboxes: `aria-label` with the task text (e.g. `"Task: Buy groceries"`)

### Web-only props

| Prop | Description |
|---|---|
| `dir` | Sets the text direction on the root container (`'ltr'`, `'rtl'`, or `'auto'`). CSS logical properties in the renderers automatically flip layout for RTL. |

The web implementation also exports `WebMarkdownTextProps` which extends `EnrichedMarkdownTextProps` with the web-only props above.

## Ignored props (native-only)

| Prop | Reason |
|---|---|
| `flavor` | The web renderer always uses full GFM capabilities. On native, `flavor` controls whether a single `TextView` (CommonMark) or container-based renderer (GitHub) is used; the DOM has no such constraint. |
| `enableLinkPreview` | iOS-only feature (native link preview on long press). |
| `allowFontScaling` / `maxFontSizeMultiplier` | React Native text scaling props. Browsers handle font scaling natively via OS accessibility settings. |
| `streamingAnimation` | Native-only tail fade-in animation. Not yet implemented on web. |
| `streamingConfig` | Native-only streaming table configuration. Not yet implemented on web. |
| `contextMenuItems` | Not supported — browsers don't allow extending the native context menu. |
| `selectionMenuConfig` | Not supported — native-only built-in selection menu actions. |
| `selectionHandleColor` | Android-only — desktop browsers don't render selection handles. |

## Not supported on web

- `EnrichedMarkdownTextInput` — native-only
- Configurable link `target` — all links open in a new tab (`target="_blank"`). Use `onLinkPress` for custom navigation.
