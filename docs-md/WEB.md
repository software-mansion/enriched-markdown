# Web Support

`EnrichedMarkdownText` and `EnrichedMarkdownTextInput` run on web using plain React and DOM primitives. They work in any React project (Next.js, Vite, Remix, CRA, etc.).

The package's `browser` field points web bundlers (webpack, Vite, Next.js, Expo web) at the web entry, so no extra resolver configuration is needed for that. One shared style module still imports `Platform` and `processColor` from `react-native`, so outside React Native the bundler has to resolve `react-native`: alias it to `react-native-web` (as most React Native web setups already do).

Markdown parsing is handled by [md4c](https://github.com/mity/md4c) compiled to WebAssembly. The WASM binary is inlined as base64 inside the bundle (`SINGLE_FILE=1`), so there is no separate `.wasm` file to serve and no build step required by consumers — just import the component and it works.

The web renderer uses semantic HTML elements (`<p>`, `<h1>`–`<h6>`, `<blockquote>`, `<ul>`, `<ol>`, `<table>`, etc.) for improved accessibility.

## Supported features

Most `EnrichedMarkdownText` features are supported on web (see [Not supported on web](#not-supported-on-web) for the exceptions), including:

- Full GFM: tables (with horizontal scroll), task lists (with checkbox interaction), strikethrough, links, images (block and inline), code blocks, LaTeX math (block and inline), admonitions (`> [!NOTE]` and the other GitHub alerts)
- Videos: `<video src>` renders as a `<video>` element with the browser's controls
- All `markdownStyle` customisation options except `spoiler`
- `onLinkPress`, `onLinkLongPress` (mapped to `contextmenu` event), `onImagePress`, `onTaskListItemPress`, `onCodeBlockPress` callbacks
- `onImagePress` — makes rendered images focusable and keyboard-activatable (Enter/Space) with a button role; the browser's right-click menu is preserved
- `onCodeBlockPress` — makes fenced code blocks clickable and keyboard-activatable (Enter/Space) with a button role, receiving the block's `code` and `language`; clicking while code text is selected does not fire
- `enableTaskListItemToggle` — set to `false` to render task list checkboxes read-only (the click is fully inert: no toggle, no `onTaskListItemPress`). The checkbox keeps its normal appearance, marked `readOnly` / `aria-disabled` and pointer-inert rather than `disabled`, matching iOS and Android
- `allowTrailingMargin`, `containerStyle`, `selectable`, `selectionColor`, `md4cFlags` (`underline`, `superscript`, `subscript`, `latexMath`, `highlight`, `hardSoftBreaks`, `preserveBlankLines`, `admonitions`)
- RTL support via the `dir` prop (CSS logical properties automatically flip blockquote borders, list indentation, etc.)

### Accessibility

- Semantic HTML elements for all markdown structures
- Images: `alt` text falls back to `title`, then URL filename, then `"Image"`
- Code blocks: `aria-label` with language when available (e.g. `"Code block: python"`)
- Math (KaTeX fallback): `role="math"` and `aria-label` with the expression content
- Task list checkboxes: `aria-label` with the task text (e.g. `"Task: Buy groceries"`)
- Videos: `aria-label` from the alt text, then `title`, then `"Video"`

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
| `linkPillContent` | Native-only - link pills are not rendered on web. |
| `linkContextMenuItems` | Native-only - link long-press menus (iOS 17+). |
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

### `EnrichedMarkdownTextInput`

The input strips its own native-only props the same way: `markdownStyle`, `markdownShortcuts`, `multiline`, `scrollEnabled`, `writingDirection`, `linkRegex`, `mentionIndicators`, `contextMenuItems`, `selectionMenuConfig`, `formatMenuConfig`, `onCaretRectChange`, `onLinkDetected`, the mention callbacks, and the React Native press props (`onPress`, `onPressIn`, `onPressOut`, `rejectResponderTermination`, `hitSlop`). Three of them are mapped instead:

| Prop | On web |
|---|---|
| `testID` | `data-testid` on the editor element. |
| `selectionColor` | Background of selected text. Without it the browser's own highlight is used. |
| `cursorColor` | The caret's color (`caret-color`). |

## Undo and redo

`EnrichedMarkdownTextInput` keeps its own undo history on web rather than using the browser's. **Cmd+Z** / **Ctrl+Z**, **Cmd+Shift+Z** / **Ctrl+Shift+Z** / **Ctrl+Y**, the Edit and context menus, and the ref's `undo()` / `redo()` all step through it, and `onChangeHistoryState` reports whether either has a step to take.

- One step is a run of typing (until a pause of half a second, a caret move or a newline), a run of Backspaces, a paste, a cut, a newline, an IME composition, or one formatting command.
- Undo restores text, formatting and selection together. A new edit clears the redo history, and `setValue` clears both, since it loads a new document.
- At most 100 steps are kept; the oldest are dropped first.
- The browser's Edit menu decides on its own whether to show Undo as available, from the browser's own history, which this input does not use. After an edit that only changed formatting, such as a toolbar Bold, it can show Undo greyed out even though `undo()` and the keyboard shortcut still work. Drive your own controls from `onChangeHistoryState`.

## Markdown output

On web, `EnrichedMarkdownTextInput` backslash-escapes characters in typed text that markdown would read as formatting, so `getMarkdown()` and `onChangeMarkdown` give back the text the user wrote: `5 * 2` becomes `5 \* 2`, a typed `# not a heading` becomes `\# not a heading`, and `snake_case` becomes `snake\_case`. Any markdown renderer shows the escaped characters as plain text.

Spaces and tabs at the start of a line are not kept, because markdown has no escape for them.

A style is left out of the markdown where markdown can't express it at that spot. Examples are underline or strikethrough on part of a word, and bold ending on punctuation right before a letter (`**Note:**text`). The text itself is kept.

## Keyboard

- **Tab** / **Shift+Tab** on a list line indent and outdent the item. On any other line, Tab inserts a tab character, and Shift+Tab moves focus out of the editor as usual.
- **Cmd+B / Cmd+I / Cmd+U** (Ctrl on Windows and Linux) toggle bold, italic and underline, and so do the browser's own formatting commands.

## Clipboard

Copy and cut put the selection on the clipboard twice: as plain text and as `text/markdown`. Paste uses the `text/markdown` flavor when it's there, so formatting copied from this editor (or any app that writes that type) comes back intact. Otherwise the plain text is read as markdown, as on iOS and Android, so pasting `- item` gives a list item. Delimiters that don't pair up stay as typed (`snake_case`, `2 * 3`). Paste and cut also work in browsers that turn clipboard events off.

## Hiding and unmounting

`EnrichedMarkdownTextInput` keeps its text, selection and undo history when React hides it and shows it again, for example inside `<Activity mode="hidden">` or a Suspense boundary that suspends again. `defaultValue` and `autoFocus` apply only to the first mount, so showing the input again doesn't reload the initial text or take focus.

A ref kept after the input unmounts still answers `getMarkdown()` with the last document, so you can save a draft from an unmount handler. `getCaretRect()` rejects with `Error('Component unmounted')`, and commands do nothing.

## Not supported on web

- `EnrichedMarkdownTextInput` link and mention commands — `setLink`, `insertLink`, `removeLink`, `insertMention`, `startMention` and `copyToClipboard` warn once and do nothing. The editor itself works on web.
- Spoilers (`||text||`) — `EnrichedMarkdownText` does not render them on web yet, and the text inside a spoiler is currently left out.
- Configurable link `target` — all links open in a new tab (`target="_blank"`). Use `onLinkPress` for custom navigation.
- Link pills — `linkVariants[pattern].pill` is ignored; such links render as ordinary links with the variant's colors and font.
