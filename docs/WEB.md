# Web Support

`EnrichedMarkdownText` runs on web using [`react-native-web`](https://necolas.github.io/react-native-web/) for the React Native primitives and [md4c](https://github.com/mity/md4c) compiled to WebAssembly for parsing. The WASM binary is bundled in the npm package — no build step is required by consumers.

The web renderer uses semantic HTML elements (`<p>`, `<h1>`–`<h6>`, `<blockquote>`, `<ul>`, `<ol>`, `<table>`, etc.) for improved accessibility.

## Supported features

All core `EnrichedMarkdownText` features are supported on web, including:

- Full GFM: tables (with horizontal scroll), task lists (with checkbox interaction), strikethrough, links, images (block and inline), code blocks, LaTeX math (block and inline)
- All `markdownStyle` customisation options
- `onLinkPress`, `onLinkLongPress` (mapped to `contextmenu` event), `onImagePress`, `onTaskListItemPress`, `onCodeBlockPress` callbacks
- `onImagePress` — makes rendered images focusable and keyboard-activatable (Enter/Space) with a button role; the browser's right-click menu is preserved
- `onCodeBlockPress` — makes fenced code blocks clickable and keyboard-activatable (Enter/Space) with a button role, receiving the block's `code` and `language`; clicking while code text is selected does not fire
- `enableTaskListItemToggle` — set to `false` to render task list checkboxes read-only (the click is fully inert: no toggle, no `onTaskListItemPress`). The checkbox keeps its normal appearance, marked `readOnly` / `aria-disabled` and pointer-inert rather than `disabled`, matching iOS and Android
- `allowTrailingMargin`, `containerStyle`, `selectable`, `selectionColor`, `md4cFlags` (`underline`, `superscript`, `subscript`, `latexMath`, `highlight`, `hardSoftBreaks`, `preserveBlankLines`)
- RTL support via the `dir` prop (CSS logical properties automatically flip blockquote borders, list indentation, etc.)

### Accessibility

- Semantic HTML elements for all markdown structures
- Images: `alt` text falls back to `title`, then URL filename, then `"Image"`
- Code blocks: `aria-label` with language when available (e.g. `"Code block: python"`)
- Math (KaTeX fallback): `role="math"` and `aria-label` with the expression content
- Task list checkboxes: `aria-label` with the task text (e.g. `"Task: Buy groceries"`)

### Web props

| Prop | Description |
|---|---|
| `dir` | Web-only. Sets the text direction on the root container (`'ltr'`, `'rtl'`, or `'auto'`). CSS logical properties in the renderers automatically flip layout for RTL. |
| `testID` | Standard React Native prop; on web it is applied to the root container as `data-testid`. |

All of these are part of the exported `EnrichedMarkdownTextProps` type for web.

## Ignored props (native-only)

These props belong to the iOS/Android API and have no effect on web. Because a
cross-platform project is usually type-checked against the native prop interface,
the same JSX compiles for web; these props are stripped before the root element
is rendered, so they never reach the DOM or trigger React "unknown prop"
warnings.

| Prop | Reason |
|---|---|
| `flavor` | The web renderer always uses full GFM capabilities. On native, `flavor` controls whether a single `TextView` (CommonMark) or container-based renderer (GitHub) is used; the DOM has no such constraint. |
| `enableLinkPreview` | iOS-only feature (native link preview on long press). |
| `allowFontScaling` / `maxFontSizeMultiplier` | React Native text scaling props. Browsers handle font scaling natively via OS accessibility settings. |
| `streamingAnimation` | Native-only tail fade-in animation. Not yet implemented on web. |
| `streamingConfig` | Native-only streaming table configuration. Not yet implemented on web. |
| `numberOfLines` / `ellipsizeMode` | Native text truncation. Not yet implemented on web. |
| `spoilerOverlay` | Native-only spoiler reveal animation. Not yet implemented on web. |
| `contextMenuItems` | Not supported - browsers don't allow extending the native context menu. |
| `selectionMenuConfig` | Not supported - native-only built-in selection menu actions. |
| `selectionHandleColor` | Android-only - desktop browsers don't render selection handles. |
| `imageRequestHeaders` | Not supported - browsers don't allow custom headers on `<img>` requests. |
| `accessibilityLabels` | VoiceOver / TalkBack announcement strings. The web renderer uses semantic HTML and native `aria-*` instead. |
| `textBreakStrategy` / `lineBreakStrategyIOS` / `writingDirection` | Native line-breaking and paragraph-direction controls. Use `dir` for web text direction. |
| `enableBlockContextMenu` | Native-only long-press copy popup on block views. |
| `onCopyPress` / `onLatexError` | Native-only callbacks. |

The stripping covers this library's own props only. Generic React Native
`ViewProps` that the native interface inherits - `accessibilityLabel`,
`onLayout`, `pointerEvents`, `hitSlop`, `nativeID` and friends - are still
forwarded to the root element and will produce React "unknown prop" warnings on
web. Use the DOM equivalents (`aria-label`, `id`, CSS) instead. `testID` is the
exception: it is mapped to `data-testid`.

## Not supported on web

- `EnrichedMarkdownTextInput` — native-only
- Configurable link `target` — all links open in a new tab (`target="_blank"`). Use `onLinkPress` for custom navigation.
