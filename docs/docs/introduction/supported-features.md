---
sidebar_label: Feature support
sidebar_position: 3
---

# Feature support

Which features are implemented in each **library** - native iOS, native
Android, and React Native - organized by component and by how the feature is
enabled. The React Native column is tracked separately because a feature can
exist in a native SDK before it is surfaced in the React Native wrapper. The
**Web** column covers React Native for Web (via
[`react-native-web`](https://necolas.github.io/react-native-web/)) and applies
only to `EnrichedMarkdownText` - the editor is native-only. For the syntax
itself see [Core concepts](/introduction/core-concepts); for per-element detail
and style properties see each platform's **Element structure** reference.

## EnrichedMarkdownText

The display component - parses a Markdown string and renders it. Runs on iOS,
Android, React Native, and the web - see the [Web support](/react-native/guides/web-support)
guide for web specifics.

### CommonMark

Available by default, no configuration required.

| Feature                     | iOS | Android | React Native | Web |
| --------------------------- | :-: | :-----: | :----------: | :-: |
| Headings                    | Yes |   Yes   |     Yes      | Yes |
| Paragraphs                  | Yes |   Yes   |     Yes      | Yes |
| Bold / italic               | Yes |   Yes   |     Yes      | Yes |
| Inline code                 | Yes |   Yes   |     Yes      | Yes |
| Links                       | Yes |   Yes   |     Yes      | Yes |
| Lists (ordered / unordered) | Yes |   Yes   |     Yes      | Yes |
| Blockquotes                 | Yes |   Yes   |     Yes      | Yes |
| Code blocks                 | Yes |   Yes   |     Yes      | Yes |
| Thematic break              | Yes |   Yes   |     Yes      | Yes |
| Images                      | Yes |   Yes   |     Yes      | Yes |

### GitHub Flavored Markdown

Enabled with `flavor="github"` on native. See [Markdown flavors](/rich-text-formatting/markdown-flavors).

:::note
The web renderer has no `flavor` prop - tables, task lists, strikethrough and
bare-URL autolinking are always enabled (the web WASM build compiles them in
unconditionally).
:::

| Feature         | iOS | Android | React Native | Web |
| --------------- | :-: | :-----: | :----------: | :-: |
| Tables          | Yes |   Yes   |     Yes      | Yes |
| Task lists      | Yes |   Yes   |     Yes      | Yes |
| Strikethrough   | Yes |   Yes   |     Yes      | Yes |
| Autolinked URLs | Yes |   Yes   |     Yes      | Yes |

### Inline extensions

Toggled independently through the `md4cFlags` prop (each off by default), not
the flavor. The one exception is **strikethrough color**, which is not an
`md4cFlags` flag but a `markdownStyle.strikethrough.color` style property.

| Feature                | iOS | Android |  React Native  | Web  |
| ---------------------- | :-: | :-----: | :------------: | :--: |
| Underline (`_text_`)   | Yes |   Yes   |      Yes       | Yes  |
| Strikethrough color    | Yes |   No    | Yes (iOS only) | Yes  |
| Superscript (`^text^`) | Yes |   Yes   |      Yes       | Yes  |
| Subscript (`~text~`)   | Yes |   Yes   |      Yes       | Yes  |
| Highlight (`==text==`) | Yes |   Yes   |      Yes       | Yes  |

### Advanced features

Each has its own page under **Rich text formatting**.

| Feature                 | iOS | Android | React Native | Web  | Learn more                                                         |
| ----------------------- | :-: | :-----: | :----------: | :--: | ------------------------------------------------------------------ |
| LaTeX math              | Yes |   Yes   |     Yes      | Yes  | [LaTeX math](/rich-text-formatting/latex-math)                     |
| Mentions                | Yes |   Yes   |     Yes      | Yes  | [Mentions](/rich-text-formatting/mentions)                         |
| Code-block highlighting | Yes |   Yes   |     Yes      |  No  | [Code-block highlighting](/rich-text-formatting/code-highlighting) |
| Markdown streaming      | Yes |   Yes   |     Yes      |  No  | [Markdown streaming](/rich-text-formatting/markdown-streaming)     |

## EnrichedMarkdownTextInput

The editor - produces a Markdown string as the user types. **Native-only**: not
available on web.

The editor is a **flat inline-formatting surface**: it supports inline styles
plus block-level headings, but not the container blocks the renderer handles.
Code blocks, tables, blockquotes, and lists are intentionally unsupported in the
input - for those, render with [`EnrichedMarkdownText`](/react-native/api-reference/enriched-markdown-text).
iOS, Android, and the React Native wrapper are at parity across the editor's
whole feature set.

### CommonMark

| Feature                     | iOS | Android | React Native |
| --------------------------- | :-: | :-----: | :----------: |
| Headings                    | Yes |   Yes   |     Yes      |
| Bold / italic               | Yes |   Yes   |     Yes      |
| Links                       | Yes |   Yes   |     Yes      |
| Inline code                 | No  |   No    |      No      |
| Lists (ordered / unordered) | No  |   No    |      No      |
| Blockquotes                 | No  |   No    |      No      |
| Code blocks                 | No  |   No    |      No      |

### GitHub Flavored Markdown

| Feature       | iOS | Android | React Native |
| ------------- | :-: | :-----: | :----------: |
| Strikethrough | Yes |   Yes   |     Yes      |
| Tables        | No  |   No    |      No      |
| Task lists    | No  |   No    |      No      |

### Inline extensions

Toggled through the editor's `toggle*` ref methods. `Spoiler` (`||text||`) is an
editor-exclusive inline style with no counterpart in the read-only renderer's
table above.

| Feature                 | iOS | Android | React Native |
| ----------------------- | :-: | :-----: | :----------: |
| Underline               | Yes |   Yes   |     Yes      |
| Spoiler (`\|\|text\|\|`)  | Yes |   Yes   |     Yes      |
| Superscript / subscript | No  |   No    |      No      |
| Highlight               | No  |   No    |      No      |

### Advanced features

| Feature  | iOS | Android | React Native | Learn more                                 |
| -------- | :-: | :-----: | :----------: | ------------------------------------------ |
| Mentions | Yes |   Yes   |     Yes      | [Mentions](/rich-text-formatting/mentions) |

Mentions are inserted as ordinary Markdown links (`[display](url)`) and styled
per URL pattern via `linkVariants` - there is no dedicated mention token.
