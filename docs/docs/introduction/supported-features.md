---
sidebar_label: Feature support
sidebar_position: 3
---

# Feature support

Which features are implemented in each **library** - native iOS, native
Android, and React Native - organized by component and by how the feature is
enabled. The **Web** column covers the React Native package's web build - a
plain React renderer that emits semantic HTML - and applies only to
`EnrichedMarkdownText`; the editor is currently native-only. For the syntax
itself see [Core concepts](/introduction/core-concepts); for per-element detail
and style properties see each platform's **Element structure** reference. For
what is missing and what is being worked on, see the [Roadmap](/misc/roadmap).

:::note
**iOS** and **Android** are the standalone native packages. They parse through
the same C++ core as React Native, so Markdown *syntax* support is identical -
the differences below are in rendering and in how much of each API surface each
package exposes. **In progress** means the parser already emits the node and the
renderer is being built.
:::

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

Enabled with `flavor="github"` on native. See [Markdown flavors](/react-native/guides/markdown-flavors).

:::note
The web renderer has no `flavor` prop - tables, task lists, strikethrough,
bare-URL autolinking and admonitions are always enabled (the web WASM build
compiles them in unconditionally).
:::

| Feature                          |     iOS     |   Android   | React Native | Web |
| -------------------------------- | :---------: | :---------: | :----------: | :-: |
| Tables                           |     Yes     | In progress |     Yes      | Yes |
| Task lists                       |     Yes     |     Yes     |     Yes      | Yes |
| Strikethrough                    |     Yes     |     Yes     |     Yes      | Yes |
| Autolinked URLs                  |     Yes     |     Yes     |     Yes      | Yes |
| Admonitions (`> [!NOTE]`)        |     Yes     |     Yes     |     Yes      | Yes |
| Videos (`<video src="url" />`)   |     No      |     No      |     Yes      | No  |

### Inline extensions

Toggled independently through the `md4cFlags` prop (most of them off by
default), not the flavor. The one exception is **strikethrough color**, which is
not an `md4cFlags` flag but a `markdownStyle.strikethrough.color` style property.

| Feature                  | iOS |   Android   |  React Native  | Web |
| ------------------------ | :-: | :---------: | :------------: | :-: |
| Underline (`_text_`)     | Yes |     Yes     |      Yes       | Yes |
| Strikethrough color      | Yes |     No      | Yes (iOS only) | Yes |
| Superscript (`^text^`)   | Yes |     Yes     |      Yes       | Yes |
| Subscript (`~text~`)     | Yes |     Yes     |      Yes       | Yes |
| Highlight (`==text==`)   | Yes |     No      |      Yes       | Yes |
| Spoilers (`\|\|text\|\|`) | Yes | In progress |      Yes       | No  |

### Advanced features

Each has its own page under **Rich text formatting**.

| Feature                 |     iOS     |   Android   | React Native | Web | Learn more                                                         |
| ----------------------- | :---------: | :---------: | :----------: | :-: | ------------------------------------------------------------------ |
| LaTeX math              |     Yes     | In progress |     Yes      | Yes | [LaTeX math](/rich-text-formatting/latex-math)                     |
| Mentions                |     No      |     No      |     Yes      | Yes | [Mentions](/rich-text-formatting/mentions)                         |
| Code-block highlighting |     No      |     No      |     Yes      | No  | [Code-block highlighting](/rich-text-formatting/code-highlighting) |
| Markdown streaming      |     No      |     No      |     Yes      | No  | [Markdown streaming](/rich-text-formatting/markdown-streaming)     |

Mentions rely on per-URL [`linkVariants`](/react-native/api-reference/style-properties), which
neither native package exposes, so neither has a mention renderer.
Code-block highlighting ships as an optional tree-sitter module that is not
compiled into either native package. Android has the fade-in machinery for
streaming internally, but no public streaming API.

## EnrichedMarkdownTextInput

The editor - produces a Markdown string as the user types.

:::important
The editor ships in the **React Native package only**. The standalone iOS and
Android packages are read-only renderers with no `EnrichedMarkdownTextInput`
equivalent, so the inline and block formatting, the format bar, and the
imperative editing API below are React Native only. Bringing the editor to the
native packages is [planned](/misc/roadmap). It is not available on web either.
:::

The editor is a **flat inline-formatting surface**: it supports inline styles
plus block-level headings and lists, but not the container blocks the renderer
handles. Code blocks, tables, and blockquotes are intentionally unsupported in
the input - for those, render with [`EnrichedMarkdownText`](/react-native/api-reference/enriched-markdown-text).

### CommonMark

| Feature                     | React Native |
| --------------------------- | :----------: |
| Headings                    |     Yes      |
| Bold / italic               |     Yes      |
| Links                       |     Yes      |
| Lists (ordered / unordered) |     Yes      |
| Inline code                 |      No      |
| Blockquotes                 |      No      |
| Code blocks                 |      No      |

### GitHub Flavored Markdown

| Feature       | React Native |
| ------------- | :----------: |
| Strikethrough |     Yes      |
| Tables        |      No      |
| Task lists    |      No      |

### Inline extensions

Toggled through the editor's `toggle*` ref methods.

| Feature                  | React Native |
| ------------------------ | :----------: |
| Underline                |     Yes      |
| Spoiler (`\|\|text\|\|`) |     Yes      |
| Superscript / subscript  |      No      |
| Highlight                |      No      |

### Advanced features

| Feature  | React Native | Learn more                                 |
| -------- | :----------: | ------------------------------------------ |
| Mentions |     Yes      | [Mentions](/rich-text-formatting/mentions) |

Mentions are inserted as ordinary Markdown links (`[display](url)`) and styled
per URL pattern via `linkVariants` - there is no dedicated mention token.
