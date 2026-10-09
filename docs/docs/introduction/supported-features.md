---
sidebar_label: Feature support
sidebar_position: 3
---

# Feature support

This page lists which features the library implements, organized by component
and by how each feature is enabled.

- The **React Native** column is the `react-native-enriched-markdown` package on
  iOS and Android. macOS runs the same iOS code with a few documented gaps - see
  [macOS support](/react-native/guides/macos).
- The **Web** column is the same package's web build, a plain React renderer
  that emits semantic HTML. The tables below cover `EnrichedMarkdownText`; the
  editor's own web gaps are listed under
  [EnrichedMarkdownTextInput](#enrichedmarkdowntextinput). See the
  [Web support](/react-native/guides/web-support) guide.

**Yes** means the feature renders with no extra work beyond the switch named in
the section heading. **No** means it does not render on that target; the
per-feature notes say what you get instead.

For the syntax itself see [Core concepts](/introduction/core-concepts); for
per-element detail and style properties see the
[Element structure](/react-native/api-reference/element-structure) reference.
For what is missing and what is being worked on, see the
[Roadmap](/misc/roadmap).

{/* UNRELEASED PLATFORMS: this page carried `iOS` and `Android` columns for the
standalone native packages, plus a note explaining that they parse through the
same C++ core so Markdown syntax support is identical and that "In progress"
meant the parser emits the node while the renderer is being built. Restore the
columns (and the per-package caveats further down) when those packages ship. */}

## EnrichedMarkdownText

The display component - parses a Markdown string and renders it.

### CommonMark

Available by default, no configuration required.

| Feature                     | React Native | Web |
| --------------------------- | :----------: | :-: |
| Headings                    |     Yes      | Yes |
| Paragraphs                  |     Yes      | Yes |
| Bold / italic               |     Yes      | Yes |
| Inline code                 |     Yes      | Yes |
| Links                       |     Yes      | Yes |
| Lists (ordered / unordered) |     Yes      | Yes |
| Blockquotes                 |     Yes      | Yes |
| Code blocks                 |     Yes      | Yes |
| Thematic break              |     Yes      | Yes |
| Images                      |     Yes      | Yes |

### GitHub Flavored Markdown

Enabled with `flavor="github"`. See
[Markdown flavors](/react-native/guides/markdown-flavors).

| Feature                        | React Native | Web |
| ------------------------------ | :----------: | :-: |
| Tables                         |     Yes      | Yes |
| Task lists                     |     Yes      | Yes |
| Strikethrough                  |     Yes      | Yes |
| Admonitions (`> [!NOTE]`)      |     Yes      | Yes |
| Videos (`<video src="url" />`) |     Yes      | No  |

Two things commonly filed under GFM are **not** gated by the flavor:

- **Bare-URL autolinks** are always parsed, in both flavors, on every target.
- **Videos** are promoted from `<video>` HTML regardless of flavor, so
  `flavor="commonmark"` parses them too. They do not render on web - the
  published WebAssembly parser predates the feature, so the node never reaches
  the web renderer.

:::note
The web renderer has no `flavor` prop - tables, task lists, strikethrough and
bare-URL autolinking are compiled into the WebAssembly build unconditionally and
are always on. Admonitions are different: on web they are a runtime
`md4cFlags.admonitions` flag, on by default and switchable like the inline
extensions below.
:::

### Inline extensions

Toggled independently through the `md4cFlags` prop (most of them off by
default), not the flavor. Two rows are **not** `md4cFlags` flags:
**strikethrough color** is the `markdownStyle.strikethrough.color` style
property, and **spoilers** are parsed unconditionally - what you configure is
the separate `spoilerOverlay` prop.

| Feature                   | React Native  | Web |
| ------------------------- | :-----------: | :-: |
| Underline (`_text_`)      |      Yes      | Yes |
| Strikethrough color       | Yes (iOS only) | Yes |
| Superscript (`^text^`)    |      Yes      | Yes |
| Subscript (`~text~`)      |      Yes      | Yes |
| Highlight (`==text==`)    |      Yes      | Yes |
| Spoilers (`\|\|text\|\|`) |      Yes      | No  |

On Android a strikethrough always uses the text color;
`markdownStyle.strikethrough.color` is honored on iOS and on web.

:::danger
Spoilers are not just unstyled on web - the node **and the text inside it** are
dropped, so `a ||secret|| b` renders as `a  b`. Do not put content behind a
spoiler if the same Markdown is rendered on web. See
[Web support](/react-native/guides/web-support#not-supported-on-web).
:::

### Advanced features

Each has its own page under **Rich text formatting**.

| Feature                 | React Native | Web | Learn more                                                         |
| ----------------------- | :----------: | :-: | ------------------------------------------------------------------ |
| LaTeX math              |     Yes      | Yes | [LaTeX math](/rich-text-formatting/latex-math)                     |
| Mentions                |     Yes      | Yes | [Mentions](/rich-text-formatting/mentions)                         |
| Code-block highlighting |     Yes      | No  | [Code-block highlighting](/rich-text-formatting/code-highlighting) |
| Markdown streaming      |     Yes      | No  | [Markdown streaming](/rich-text-formatting/markdown-streaming)     |

LaTeX math on web needs the optional `katex` peer dependency; without it the
formula falls back to its raw `$...$` source. Code-block highlighting on web
renders a plain, uncolored `<pre><code>`. The two streaming props are stripped
on web.

## EnrichedMarkdownTextInput

The editor - produces a Markdown string as the user types.

:::important
The editor runs on iOS, Android, macOS and web. On web the link and mention
commands - `setLink`, `insertLink`, `removeLink`, `insertMention`,
`startMention` - and `copyToClipboard` warn once and do nothing; everything
else, including every inline and block command and all the `onChange*` events,
works. See [Web support](/react-native/guides/web-support#not-supported-on-web).
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
