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
- The **iOS** column is the standalone Swift package (0.4.0), and the
  **Android** column is the standalone Android library (0.3.0). Both parse
  through the same C++ core as the React Native package, but neither has a
  `flavor` switch or an `md4cFlags` prop - the per-section notes name their
  native switches. They ship `EnrichedMarkdownText` only, so they do not appear
  in the editor tables. See [iOS](/ios/basics/installation) and
  [Android](/android/basics/installation) installation.
- The **Web** column is the same package's web build, a plain React renderer
  that emits semantic HTML. In the editor tables it is the experimental web
  editor. See the [Web support](/react-native/guides/web-support) and
  [Web editor](/react-native/guides/web-editor) guides.

**Yes** means the feature renders with no extra work beyond the switch named in
the section heading. **No** means it does not render on that target; the
per-feature notes say what you get instead.

For the syntax itself see [Core concepts](/introduction/core-concepts); for
per-element detail and style properties see the Element structure reference for
[React Native](/react-native/api-reference/element-structure),
[iOS](/ios/api-reference/element-structure) or
[Android](/android/api-reference/element-structure).
For what is missing and what is being worked on, see the
[Roadmap](/misc/roadmap).

## EnrichedMarkdownText

The display component - parses a Markdown string and renders it.

### CommonMark

Available by default, no configuration required.

| Feature                     | React Native | iOS | Android | Web |
| --------------------------- | :----------: | :-: | :-----: | :-: |
| Headings                    |     Yes      | Yes |   Yes   | Yes |
| Paragraphs                  |     Yes      | Yes |   Yes   | Yes |
| Bold / italic               |     Yes      | Yes |   Yes   | Yes |
| Inline code                 |     Yes      | Yes |   Yes   | Yes |
| Links                       |     Yes      | Yes |   Yes   | Yes |
| Lists (ordered / unordered) |     Yes      | Yes |   Yes   | Yes |
| Blockquotes                 |     Yes      | Yes |   Yes   | Yes |
| Code blocks                 |     Yes      | Yes |   Yes   | Yes |
| Thematic break              |     Yes      | Yes |   Yes   | Yes |
| Images                      |     Yes      | Yes |   Yes   | Yes |

### GitHub Flavored Markdown

In React Native, enabled with `flavor="github"` - see
[Markdown flavors](/react-native/guides/markdown-flavors). The standalone iOS
and Android SDKs have no flavor switch: tables, task lists and strikethrough are
always on there.

| Feature                        | React Native | iOS | Android | Web |
| ------------------------------ | :----------: | :-: | :-----: | :-: |
| Tables                         |     Yes      | Yes |   Yes   | Yes |
| Task lists                     |     Yes      | Yes |   Yes   | Yes |
| Strikethrough                  |     Yes      | Yes |   Yes   | Yes |
| Admonitions (`> [!NOTE]`)      |     Yes      | Yes |   Yes   | Yes |
| Videos (`<video src="url" />`) |     Yes      | No  |   No    | Yes |

On iOS and Android, **admonitions** are a parsing switch, off by default:
`MarkdownParsingOptions(admonitions: true)` on iOS and
`MarkdownOptions(admonitions = true)` on Android - see
[iOS parser extensions](/ios/guides/parser-extensions#admonitions) and
[Android parser extensions](/android/guides/parser-extensions#admonitions).
On Android, a table nested inside a list item or blockquote is not rendered.

:::warning
Neither standalone SDK renders videos. iOS drops the `<video>` block; on
Android a `<video>` block currently prevents the **whole document** from
rendering, so do not feed one to the Android `EnrichedMarkdownText`.
:::

Two things commonly filed under GFM are **not** gated by the flavor:

- **Bare-URL autolinks** are always parsed in React Native, in both flavors,
  and on web. On iOS and Android they are the `permissiveAutolinks` parsing
  switch, on by default.
- **Videos** are promoted from `<video>` HTML regardless of flavor, so
  `flavor="commonmark"` parses them too. On web there is no flavor to set and
  no build flag to enable: the tag renders in the browser's own `<video>`
  player.

:::note
The web renderer has no `flavor` prop - tables, task lists, strikethrough and
bare-URL autolinking are compiled into the WebAssembly build unconditionally and
are always on. Admonitions are different: on web they are a runtime
`md4cFlags.admonitions` flag, on by default and switchable like the inline
extensions below.
:::

### Inline extensions

Toggled independently, not by the flavor, and most of them off by default:

- **React Native and web** - the `md4cFlags` prop.
- **iOS** - `MarkdownParsingOptions(...)`, passed as the view's `options:`
  argument. See [Parser extensions](/ios/guides/parser-extensions).
- **Android** - `MarkdownOptions(...)`, passed as the `options` parameter. See
  [Parser extensions](/android/guides/parser-extensions).

Two rows are **not** parsing switches on any target: **strikethrough color** is
a style property (`markdownStyle.strikethrough.color` in React Native, the
`Strikethrough()` theme element on iOS, `strikethrough { color }` on Android),
and **spoilers** are parsed unconditionally - what you configure is the
separate spoiler overlay.

| Feature                   |  React Native  | iOS | Android | Web |
| ------------------------- | :------------: | :-: | :-----: | :-: |
| Underline (`_text_`)      |      Yes       | Yes |   Yes   | Yes |
| Strikethrough color       | Yes (iOS only) | Yes |   Yes   | Yes |
| Superscript (`^text^`)    |      Yes       | Yes |   Yes   | Yes |
| Subscript (`~text~`)      |      Yes       | Yes |   Yes   | Yes |
| Highlight (`==text==`)    |      Yes       | Yes |   Yes   | Yes |
| Spoilers (`\|\|text\|\|`) |      Yes       | Yes |   Yes   | No  |

In the React Native package on Android a strikethrough always uses the text
color; `markdownStyle.strikethrough.color` is honored on iOS and on web. The
standalone Android SDK does honor `strikethrough { color }`.

:::danger
Spoilers are not just unstyled on web - the node **and the text inside it** are
dropped, so `a ||secret|| b` renders as `a  b`. Do not put content behind a
spoiler if the same Markdown is rendered on web. See
[Web support](/react-native/guides/web-support#not-supported-on-web).
:::

### Advanced features

Each has its own page - under **Rich text formatting**, or under the React Native
**Guides** when the feature exists only in the React Native package.

| Feature                 | React Native | iOS | Android | Web | Learn more                                                         |
| ----------------------- | :----------: | :-: | :-----: | :-: | ------------------------------------------------------------------ |
| LaTeX math              |     Yes      | Yes |   Yes   | Yes | [LaTeX math](/rich-text-formatting/latex-math)                     |
| Mentions                |     Yes      | Yes |   No    | Yes | [Mentions](/rich-text-formatting/mentions)                         |
| Code-block highlighting |     Yes      | Yes |   Yes   | No  | [Code-block highlighting](/rich-text-formatting/code-highlighting) |
| Markdown streaming      |     Yes      | Yes |   No    | No  | [Markdown streaming](/rich-text-formatting/markdown-streaming)     |
| Link pills              |     Yes      | No  |   No    | No  | [Link pills](/react-native/guides/link-pills)                      |
| Link menus              |     Yes      | No  |   No    | No  | [Link menus](/react-native/guides/link-menus)                      |

LaTeX math on web needs the optional `katex` peer dependency; without it the
formula falls back to its raw `$...$` source. Code-block highlighting on web
renders a plain, uncolored `<pre><code>`. The two streaming props are stripped
on web. Link pills are drawn by the native text stack, so on web those links
render as ordinary links with the variant's colors; custom link menus are an
iOS 17+ feature, and a long press on web is the `contextmenu` event delivered
to `onLinkLongPress`.

On the standalone SDKs, the advanced features that render are optional add-ons:

- **LaTeX math** - on iOS, add the optional `EnrichedMarkdownLaTeX` product and
  apply `.markdownLaTeX()` (see [iOS LaTeX math](/ios/guides/latex-math)); on
  Android, add the optional `com.swmansion.enriched.markdown:math` artifact
  and register `LatexMathPlugin`, which turns on parsing and rendering
  together (see [Android LaTeX math](/android/guides/latex-math)).
- **Code-block highlighting** - on iOS, add the optional
  `EnrichedMarkdownSyntaxHighlighting` product and apply
  `.markdownSyntaxHighlighting()` (see
  [Syntax highlighting](/ios/guides/syntax-highlighting)); on Android, add the
  optional `com.swmansion.enriched.markdown:code-highlight` artifact and
  register `CodeHighlightPlugin` (see
  [Android code highlighting](/android/guides/code-highlighting)).
- **Markdown streaming** - on iOS, add the optional
  `EnrichedMarkdownStreaming` product and apply `.markdownStreaming()` (see
  [Markdown streaming](/ios/guides/markdown-streaming)). The Android package
  has no streaming API yet.
- **Mentions** - built into the iOS package, with no add-on: style each URL
  scheme with a
  [`Link(matching:)`](/ios/api-reference/style-properties#link-matching) theme
  element and route taps in `openURL` (see
  [Mentions](/rich-text-formatting/mentions#displaying-mentions)). On Android,
  mentions render and respond to taps like any other link, but cannot be styled
  apart.

## EnrichedMarkdownTextInput

The editor - produces a Markdown string as the user types.

:::important
The editor runs on iOS, Android and macOS. Its web build is
<ExperimentalBadge /> and covers less: no Markdown shortcuts, link or mention
commands, auto-link detection or `markdownStyle.linkVariants`. See
[Web editor](/react-native/guides/web-editor).
:::

The editor is a **flat inline-formatting surface**: it supports inline styles
plus block-level headings and lists, but not the container blocks the renderer
handles. Code blocks, tables, and blockquotes are intentionally unsupported in
the input - for those, render with [`EnrichedMarkdownText`](/react-native/api-reference/enriched-markdown-text).

### CommonMark

| Feature                     | React Native |   Web   |
| --------------------------- | :----------: | :-----: |
| Headings                    |     Yes      |   Yes   |
| Bold / italic               |     Yes      |   Yes   |
| Links                       |     Yes      | Partial |
| Lists (ordered / unordered) |     Yes      |   Yes   |
| Inline code                 |      No      |   No    |
| Blockquotes                 |      No      |   No    |
| Code blocks                 |      No      |   No    |

On web, links that arrive in the Markdown are kept and rendered, but there are
no link commands to create or edit one.

### GitHub Flavored Markdown

| Feature       | React Native | Web |
| ------------- | :----------: | :-: |
| Strikethrough |     Yes      | Yes |
| Tables        |      No      | No  |
| Task lists    |      No      | No  |

### Inline extensions

Toggled through the editor's `toggle*` ref methods.

| Feature                  | React Native | Web |
| ------------------------ | :----------: | :-: |
| Underline                |     Yes      | Yes |
| Spoiler (`\|\|text\|\|`) |     Yes      | Yes |
| Superscript / subscript  |      No      | No  |
| Highlight                |      No      | No  |

### Advanced features

| Feature  | React Native | Web | Learn more                                 |
| -------- | :----------: | :-: | ------------------------------------------ |
| Mentions |     Yes      | No  | [Mentions](/rich-text-formatting/mentions) |

Mentions are inserted as ordinary Markdown links (`[display](url)`) and styled
per URL pattern via `linkVariants` - there is no dedicated mention token.
