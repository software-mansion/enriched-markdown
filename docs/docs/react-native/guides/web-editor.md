---
title: Web editor
sidebar_label: Web editor
sidebar_position: 3.5
sidebar_class_name: sidebar-experimental
---

# Web editor <ExperimentalBadge />

`EnrichedMarkdownTextInput` runs on web as a `contentEditable` editor built from
plain React and DOM primitives. It keeps its own document model, renders it into
the editable element and serializes it back to Markdown, so
[`getMarkdown()`](/react-native/api-reference/enriched-markdown-text-input#getmarkdown-promisestring)
and
[`onChangeMarkdown`](/react-native/api-reference/enriched-markdown-text-input#onchangemarkdown)
behave as they do on iOS and Android.

:::warning Experimental
The web editor is **experimental**. Its props, ref methods and Markdown output
may change in breaking ways, including in nightly releases, before it is marked
stable. Pin an exact version if you depend on it, and expect a smaller feature
set than on native - see [Not supported on web](#not-supported-on-web).
:::

## Setup

The editor ships in the same web entry as `EnrichedMarkdownText`, so the bundler
setup in [Web support](/react-native/guides/web-support#setup) covers it - there
is nothing else to install. Import it as on native:

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
        onClick={() => ref.current?.toggleBold()}>
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

The parser is warmed up when the module loads, so the first `defaultValue` is
ready almost immediately. Commands issued while it is still parsing wait for it
rather than acting on an empty document.

## Supported

### Formatting

| Kind   | On web                                                                                                                                             |
| ------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Inline | Bold, italic, underline, strikethrough, spoiler                                                                                                    |
| Block  | Headings (H1-H6), bullet lists, numbered lists, nested lists                                                                                       |
| Links  | Links that arrive through `defaultValue`, `setValue`, `insertText` or paste are kept and rendered; they cannot be created or edited on web yet |

### Props

| Prop                                   | Notes                                                                                                                       |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `defaultValue`                         | Read once, on first mount.                                                                                                  |
| `placeholder` / `placeholderTextColor` |                                                                                                                             |
| `editable`                             |                                                                                                                             |
| `autoFocus`                            | First mount only.                                                                                                           |
| `spellCheck`                           | Read once, on first mount.                                                                                                  |
| `style`                                | React `CSSProperties`, applied to the editor `<div>`. React Native shorthands such as `paddingHorizontal` do not apply. |
| `className`                            | Added next to the editor's own class.                                                                                       |
| `markdownStyle`                        | Everything except `linkVariants` - see [Styling](#styling).                                                                 |
| `selectionColor`                       | Background of selected text. Without it the browser's own highlight is used.                                                |
| `cursorColor`                          | The caret's color (`caret-color`).                                                                                          |
| `testID`                               | Rendered as `data-testid`.                                                                                                  |

Any other DOM attribute (`id`, `aria-*`, `data-*`, DOM event handlers) is
forwarded to the editor `<div>`, except `children`, `dangerouslySetInnerHTML`
and `contentEditable`, which the editor owns.

### Events

`onChangeText`, `onChangeMarkdown`, `onChangeSelection`, `onChangeState`,
`onChangeHistoryState`, `onFocus` and `onBlur`.

`onChangeMarkdown` serializes the whole document on every edit, so pass it only
when you need it. Without it nothing is serialized until you call
`getMarkdown()`.

### Ref methods

| Method                                                                                                    | Notes                                                       |
| --------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| `focus()`, `blur()`                                                                                       |                                                             |
| `setValue(markdown)`                                                                                      | Clears undo and redo history.                               |
| `getMarkdown()`                                                                                           | Still answers after unmount, with the last document.        |
| `insertText(text)`                                                                                        | Parsed as Markdown, as on native.                           |
| `setSelection(start, end)`                                                                                |                                                             |
| `getCaretRect()`                                                                                          | Rejects with `Error('Component unmounted')` after unmount.  |
| `toggleBold()`, `toggleItalic()`, `toggleUnderline()`, `toggleStrikethrough()`, `toggleSpoiler()`         |                                                             |
| `toggleHeading(level)`, `toggleUnorderedList()`, `toggleOrderedList()`, `indentList()`, `outdentList()`   |                                                             |
| `undo()`, `redo()`                                                                                        | See [Undo and redo](#undo-and-redo).                        |
| `measure()`, `measureInWindow()`, `measureLayout()`                                                       | Same contract as the React Native host-component methods.   |

## Styling

`markdownStyle` works as on native, except `linkVariants`, which is ignored on
web: per-URL link styling is not implemented there yet. Each key the web editor
honors is set on the editor element as a CSS custom property, so every instance
can carry its own theme - for example a light and a dark one:

```tsx
<EnrichedMarkdownTextInput
  style={{ color: isDark ? '#e7eaf6' : '#232736' }}
  markdownStyle={isDark ? darkInputStyle : lightInputStyle}
/>
```

`markdownStyle` covers formatting only. Set the base font, size, line height,
text color and background through `style` or `className` - the editor's own
defaults have zero specificity, so a class of yours wins over them.
Strikethrough and list-marker colors are not part of `markdownStyle` on any
platform, and keep their defaults.

## Undo and redo

The editor keeps its own undo history on web rather than using the browser's.
**Cmd+Z** / **Ctrl+Z**, **Cmd+Shift+Z** / **Ctrl+Shift+Z** / **Ctrl+Y**, the
Edit and context menus, and the ref's `undo()` / `redo()` all step through it,
and `onChangeHistoryState` reports whether either has a step to take.

- One step is a run of typing (until a pause of half a second, a caret move or a
  newline), a run of Backspaces, a paste, a cut, a newline, an IME composition,
  or one formatting command.
- Undo restores text, formatting and selection together. A new edit clears the
  redo history, and `setValue` clears both, since it loads a new document.
- At most 100 steps are kept; the oldest are dropped first.

:::note
The browser's Edit menu decides on its own whether Undo is available, from the
browser's own history, which this editor does not use. After an edit that only
changed formatting, such as a toolbar Bold, it can show Undo greyed out even
though `undo()` and the keyboard shortcut still work. Drive your own controls
from `onChangeHistoryState`.
:::

## Markdown output

Characters in typed text that Markdown would read as formatting are
backslash-escaped, so `getMarkdown()` and `onChangeMarkdown` give back the text
the user wrote: `5 * 2` becomes `5 \* 2`, a typed `# not a heading` becomes
`\# not a heading`, and `snake_case` becomes `snake\_case`. Any Markdown
renderer shows the escaped characters as plain text.

Spaces and tabs at the start of a line are not kept, because Markdown has no
escape for them.

A style is left out of the Markdown where Markdown can't express it at that
spot - for example underline or strikethrough on part of a word, or bold ending
on punctuation right before a letter (`**Note:**text`). The text itself is kept.

## Keyboard

- **Tab** / **Shift+Tab** on a list line indent and outdent the item. On any
  other line, Tab inserts a tab character, and Shift+Tab moves focus out of the
  editor as usual.
- **Cmd+B** / **Cmd+I** / **Cmd+U** (Ctrl on Windows and Linux) toggle bold,
  italic and underline, and so do the browser's own formatting commands.

## Clipboard

Copy and cut put the selection on the clipboard twice: as plain text and as
`text/markdown`. Paste uses the `text/markdown` flavor when it is there, so
formatting copied from this editor (or any app that writes that type) comes back
intact. Otherwise the plain text is read as Markdown, as on iOS and Android, so
pasting `- item` gives a list item. Delimiters that don't pair up stay as typed
(`snake_case`, `2 * 3`).

## Hiding and unmounting

The editor keeps its text, selection and undo history when React hides it and
shows it again - for example inside `<Activity mode="hidden">` or a Suspense
boundary that suspends again. `defaultValue` and `autoFocus` apply only to the
first mount, so showing the editor again doesn't reload the initial text or take
focus.

A ref kept after the editor unmounts still answers `getMarkdown()` with the last
document, so you can save a draft from an unmount handler. `getCaretRect()`
rejects with `Error('Component unmounted')`, and commands do nothing.

## Ignored props (native-only)

These props are stripped before the editor `<div>` renders, so they never reach
the DOM or trigger React unknown-prop warnings:

`markdownShortcuts`, `multiline`, `scrollEnabled`,
`writingDirection`, `linkRegex`, `onLinkDetected`, `mentionIndicators`,
`onStartMention`, `onChangeMention`, `onEndMention`, `contextMenuItems`,
`selectionMenuConfig`, `formatMenuConfig`, `onCaretRectChange`, and the React
Native press props (`onPress`, `onPressIn`, `onPressOut`,
`rejectResponderTermination`, `hitSlop`).

:::caution
`onKeyPress` and `autoCapitalize` are **not** stripped: they share a name with
DOM props and reach the `<div>` as those. `onKeyPress` is then the browser's
`keypress` event, which does not fire for Backspace, Delete, arrow keys or IME
input, so it is no replacement for the native event.
:::

## Not supported on web

- **Link and mention commands** - `setLink`, `insertLink`, `removeLink`,
  `insertMention`, `startMention` and `copyToClipboard` warn once and do
  nothing.
- **Markdown shortcuts** - typing `# ` or `- ` does not turn the line into a
  heading or list.
- **Auto-link detection** - `linkRegex` and `onLinkDetected` are ignored.
- **Mentions** - there is no mention flow, and the mention events never fire.
- **Custom menus** - `contextMenuItems`, `selectionMenuConfig` and
  `formatMenuConfig` are ignored; the browser's own context menu is shown.
- **`markdownStyle.linkVariants`** - see [Styling](#styling).
- **`onCaretRectChange`** - call `getCaretRect()` instead.

Report problems on
[GitHub](https://github.com/software-mansion-labs/react-native-enriched-markdown/issues)
and mention that you are on web.
