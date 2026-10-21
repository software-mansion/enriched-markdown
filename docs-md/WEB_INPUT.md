# Web Editor [![Experimental](https://img.shields.io/badge/-experimental-orange "Experimental: this feature is still taking shape and may get breaking changes, including in nightly releases.")](#experimental-status)

`EnrichedMarkdownTextInput` runs on web as a `contentEditable` editor built from plain React and DOM primitives. It keeps its own document model, renders it into the editable element, and serializes it back to Markdown, so `getMarkdown()` and `onChangeMarkdown` work the same way they do on iOS and Android.

> [!WARNING]
> The web editor is **experimental**. Its props, ref methods and Markdown output may change in breaking ways, including in nightly releases, before it is marked stable. Pin an exact version if you depend on it.

## Experimental status

What "experimental" means here:

- Breaking changes can land in any release, nightly builds included, without a major version bump.
- Parts of the native API are missing on web (see [Not supported on web](#not-supported-on-web)); some will be added, and adding them may change existing behavior.
- Report problems on [GitHub issues](https://github.com/software-mansion-labs/react-native-enriched-markdown/issues) and mention that you are on web.

## Setup

The editor ships in the same web entry as `EnrichedMarkdownText`, so the bundler setup in [Web Support](WEB.md) covers it; there is nothing else to install. Import it as on native:

```tsx
import { useRef, useState } from 'react';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
  type StyleState,
} from 'react-native-enriched-markdown';

export default function Editor() {
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [state, setState] = useState<StyleState | null>(null);

  return (
    <>
      <button
        aria-pressed={state?.bold.isActive ?? false}
        onClick={() => ref.current?.toggleBold()}
      >
        Bold
      </button>
      <EnrichedMarkdownTextInput
        ref={ref}
        defaultValue="Hello **web**"
        placeholder="Type here..."
        onChangeState={setState}
        style={{ minHeight: 96, padding: 12 }}
      />
    </>
  );
}
```

The parser is warmed up when the module loads, so the first `defaultValue` is ready almost immediately. Commands issued while it is still parsing wait for it rather than acting on an empty document.

## Supported

### Formatting

| Kind | Supported on web |
|---|---|
| Inline | Bold, italic, underline, strikethrough, spoiler |
| Block | Headings (H1–H6), bullet lists, numbered lists, nested lists |
| Links | Links that come in through `defaultValue`, `setValue`, `insertText` or paste are kept and rendered; they cannot be created or edited from the web editor yet |

### Props

| Prop | Notes |
|---|---|
| `defaultValue` | Read once, on first mount. |
| `placeholder` / `placeholderTextColor` | |
| `editable` | |
| `autoFocus` | First mount only. |
| `spellCheck` | Read once, on first mount. |
| `style` | React `CSSProperties`, applied to the editor `<div>`. React Native style shorthands (`paddingHorizontal`, …) do not apply. |
| `className` | Added next to the editor's own class. |
| `markdownStyle` | Everything except `linkVariants`; see [Styling](#styling). |
| `selectionColor` | Background of selected text. Without it the browser's own highlight is used. |
| `cursorColor` | The caret's color (`caret-color`). |
| `testID` | Rendered as `data-testid`. |

Any other DOM attribute (`id`, `aria-*`, `data-*`, DOM event handlers) is forwarded to the editor `<div>`, except `children`, `dangerouslySetInnerHTML` and `contentEditable`, which the editor owns.

### Events

`onChangeText`, `onChangeMarkdown`, `onChangeSelection`, `onChangeState`, `onChangeHistoryState`, `onFocus`, `onBlur`.

`onChangeMarkdown` serializes the whole document on every edit, so only pass it when you need it; without it, nothing is serialized until you call `getMarkdown()`.

### Ref methods

| Method | Notes |
|---|---|
| `focus()`, `blur()` | |
| `setValue(markdown)` | Clears undo and redo history. |
| `getMarkdown()` | Still answers after unmount, with the last document. |
| `insertText(text)` | Parsed as Markdown, as on native. |
| `setSelection(start, end)` | |
| `getCaretRect()` | Rejects with `Error('Component unmounted')` after unmount. |
| `toggleBold()`, `toggleItalic()`, `toggleUnderline()`, `toggleStrikethrough()`, `toggleSpoiler()` | |
| `toggleHeading(level)`, `toggleUnorderedList()`, `toggleOrderedList()`, `indentList()`, `outdentList()` | |
| `undo()`, `redo()` | See [Undo and redo](#undo-and-redo). |
| `measure()`, `measureInWindow()`, `measureLayout()` | Same contract as the React Native host-component methods. |

## Styling

`markdownStyle` works as on native, except `linkVariants`, which is ignored on web: per-URL link styling is not implemented there yet. Each key the web editor honors is set on the editor element as a CSS custom property, so every instance can carry its own theme, for example a light and a dark one:

```tsx
<EnrichedMarkdownTextInput
  style={{ color: isDark ? '#e7eaf6' : '#232736' }}
  markdownStyle={isDark ? darkInputStyle : lightInputStyle}
/>
```

`markdownStyle` covers formatting only. Set the base font, size, line height, text color and background through `style` or `className`; the editor's own defaults have zero specificity, so a class of yours wins over them. Strikethrough and list-marker colors are not part of `markdownStyle` on any platform, and keep their defaults.

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

## Ignored props (native-only)

These props are stripped before the editor `<div>` is rendered, so they never reach the DOM or trigger React "unknown prop" warnings:

`markdownShortcuts`, `multiline`, `scrollEnabled`, `writingDirection`, `linkRegex`, `onLinkDetected`, `mentionIndicators`, `onStartMention`, `onChangeMention`, `onEndMention`, `contextMenuItems`, `selectionMenuConfig`, `formatMenuConfig`, `onCaretRectChange`, and the React Native press props (`onPress`, `onPressIn`, `onPressOut`, `rejectResponderTermination`, `hitSlop`).

`onKeyPress` and `autoCapitalize` are not stripped: they share a name with DOM props and reach the `<div>` as those. `onKeyPress` is then the browser's `keypress` event, which does not fire for Backspace, Delete, arrow keys or IME input, so it is not a replacement for the native event.

## Not supported on web

- **Link and mention commands** — `setLink`, `insertLink`, `removeLink`, `insertMention`, `startMention` and `copyToClipboard` warn once and do nothing.
- **Markdown shortcuts** — typing `# ` or `- ` does not turn the line into a heading or list.
- **Auto-link detection** — `linkRegex` and `onLinkDetected` are ignored.
- **Mentions** — no mention flow; mention events never fire.
- **Custom menus** — `contextMenuItems`, `selectionMenuConfig` and `formatMenuConfig` are ignored; the browser's own context menu is shown.
- **`markdownStyle.linkVariants`** — see [Styling](#styling).
- **`onCaretRectChange`** — use `getCaretRect()` instead.
