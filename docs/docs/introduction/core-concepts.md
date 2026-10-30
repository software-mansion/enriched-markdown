---
sidebar_label: Core concepts
sidebar_position: 2
---

# Core concepts

In Enriched Markdown, **Markdown is the shared format** between the two components. `EnrichedMarkdownTextInput` _produces_ Markdown as the user types, and `EnrichedMarkdownText` _consumes_ Markdown to render it. If you understand the Markdown syntax below, you understand what both components can express.

This page is a primer on that syntax and the flavor that decides which parts of it are available. It's platform-neutral - the same Markdown string drives every target the library renders to.

## What is Markdown?

Markdown is a lightweight plain-text formatting syntax. You write ordinary text and add a few punctuation markers to convey structure - `**` around a word for **bold**, a leading `#` for a heading - and a parser turns that into styled, structured content.

It's the format behind README files, GitHub comments, chat apps, and note-taking tools. Its appeal is that the source stays readable as plain text: `**bold**` reads as "bold" even before it's rendered.

In this library the Markdown string is the thing you store, send over the wire, and feed back into a renderer - the styled output is derived from it.

## Block vs. inline elements

Markdown elements fall into two families, and the distinction matters when you customize or combine them:

- **Block elements** occupy whole lines and stack vertically: headings, paragraphs, lists, blockquotes, code blocks, tables. They establish structure.
- **Inline elements** live _within_ a block and style a run of text: bold, italic, strikethrough, inline code, links.

Inline elements inherit typography from the block that contains them - bold text inside a heading takes the heading's size. For the full breakdown of which elements exist, how they nest, and how inheritance works, see the [Element structure](/react-native/api-reference/element-structure) reference.

## Markdown syntax

The examples below show the **raw Markdown** you write, and describe what it renders to. This is the CommonMark core that every target supports, in both flavors.

:::tip
This page is a practical primer, not an exhaustive reference. For the complete, authoritative rules of the core syntax, see the [CommonMark specification](https://spec.commonmark.org/).
:::

### Inline formatting

Inline formatting applies to a span of characters _inside_ a paragraph.

```md
**bold** and __also bold__
*italic* and _also italic_
`inline code`
```

- `**text**` or `__text__` - **bold**
- `*text*` or `_text_` - _italic_
- `` `text` `` - `inline code`, rendered in a monospace font

Strikethrough (`~~text~~`) is **not** part of the CommonMark core - it is a GitHub Flavored Markdown extension, covered under [Markdown flavors](#markdown-flavors) below.

:::caution
With certain extensions enabled, the meaning of `__text__` and `_text_` may change. The `*` syntax never changes, so it is the safer choice. Learn more about the `underline` extension: the [`md4cFlags`](/react-native/api-reference/enriched-markdown-text#md4cflags) prop in React Native, [`MarkdownParsingOptions`](/ios/guides/parser-extensions#underline) on iOS, and [`MarkdownOptions`](/android/guides/parser-extensions#underline) on Android.
:::

You can combine them - for example `***bold italic***` applies _**bold and italic together**_.

### Headings

A heading is a whole line prefixed with one to six `#` characters. More hashes mean a deeper level (`#` is the largest, `######` the smallest).

```md
# Heading 1

## Heading 2

### Heading 3
```

Headings are **block-level**: the marker applies to the entire line, not a character range.

### Links

A link is link text in square brackets followed by a URL in parentheses.

```md
[React Native](https://reactnative.dev)
```

:::note
Links in `EnrichedMarkdownText` are interactive, and you decide how to open them. In the React Native package, taps surface through the `onLinkPress` callback; on iOS they go through the SwiftUI [`openURL`](/ios/api-reference/enriched-markdown-text#openurl) environment action; on Android they go to the [`onLinkClick`](/android/api-reference/enriched-markdown-text#onlinkclick) parameter.
:::

### Lists

Unordered lists use `-`, `*`, or `+` as the bullet. Ordered lists use a number followed by a period. Indent to nest.

```md
- First item
- Second item
  - Nested item
  - Another nested item

1. Step one
2. Step two
3. Step three
```

:::tip
An ordered list does not have to start at `1.` - begin with the number you want, for example `12.`.
:::

### Blockquotes

Prefix a line with `>` to quote it. Blockquotes can contain other Markdown and can be nested.

```md
> This is a quote.
>
> > And this is a quote inside a quote.
```

### Code blocks

Fence a block of code with triple backticks. An optional language after the opening fence enables syntax highlighting in the React Native package on iOS and Android. The standalone iOS package highlights code only when you add the optional `EnrichedMarkdownSyntaxHighlighting` product and apply [`.markdownSyntaxHighlighting()`](/ios/guides/syntax-highlighting), and the standalone Android package only when you add the optional `code-highlight` artifact and enable [`CodeHighlightPlugin`](/android/guides/code-highlighting).

````md
```tsx
const answer = 42;
```
````

:::important
See [Code-block highlighting](/rich-text-formatting/code-highlighting) for the highlighting details.
:::

### Horizontal rules

Three or more `-`, `*`, or `_` on their own line render a divider.

```md
---
```

## Markdown flavors

There is a small CommonMark core that every Markdown parser agrees on (everything above), plus optional extensions layered on top. How you choose between them depends on the package:

<CodeTabs groupId="platform">

<Tab label="React Native">

The React Native package exposes this through the `flavor` prop:

- **CommonMark** (default) - the standard core syntax.
- **GitHub Flavored Markdown (GFM)** - CommonMark plus **tables**, **task lists**, **strikethrough** and much more. Opt in with `flavor="github"`.

```tsx
<EnrichedMarkdownText flavor="github" markdown={markdown} />
```

</Tab>
<Tab label="iOS">

The standalone iOS SDK has no `flavor` selector. GFM's **tables**, **task lists** and **strikethrough** are always on, and so are spoilers. The remaining extensions - underline, superscript, subscript, highlight, admonitions, hard soft breaks, preserved blank lines and permissive autolinks - are individual `MarkdownParsingOptions` (`Md4cFlags` is only a deprecated alias):

```swift
EnrichedMarkdownText(markdown, options: MarkdownParsingOptions(underline: true, admonitions: true))
```

LaTeX math is not a parsing option on iOS: adding the optional `EnrichedMarkdownLaTeX` product and applying `.markdownLaTeX()` turns parsing and rendering on together - see [LaTeX math](/ios/guides/latex-math).

See [Parser extensions](/ios/guides/parser-extensions).

</Tab>
<Tab label="Android">

The standalone Android SDK has no `flavor` selector either. GFM's **tables**, **task lists** and **strikethrough** are always on, and so are spoilers. The remaining extensions - underline, superscript, subscript, highlight, admonitions, hard soft breaks, preserved blank lines and permissive autolinks - are individual `MarkdownOptions`:

```kotlin
EnrichedMarkdownText(
  markdown = markdown,
  options = MarkdownOptions(underline = true, admonitions = true),
)
```

LaTeX math is not a parsing option on Android either: enabling `LatexMathPlugin` from the optional `math` artifact turns parsing and rendering on together - see [LaTeX math](/android/guides/latex-math).

See [Parser extensions](/android/guides/parser-extensions).

</Tab>

</CodeTabs>

:::note
The web build has no `flavor` prop - it always parses GFM. See [Web support](/react-native/guides/web-support).
:::

Tables render with column alignment, rich text in cells, and header styling; task lists become interactive checkboxes you can respond to. See the `EnrichedMarkdownText` reference for [React Native](/react-native/api-reference/enriched-markdown-text), [iOS](/ios/api-reference/enriched-markdown-text) or [Android](/android/api-reference/enriched-markdown-text) for the parameters that surface these.

For an in-depth look at why flavors exist, everything GFM adds, and how extensions are enabled, see [Markdown flavors](/react-native/guides/markdown-flavors) in the React Native guides. Some of the extensions themselves are defined by the [GitHub Flavored Markdown spec](https://github.github.com/gfm/).

## How the components use Markdown

Bringing it back to the two components:

- **`EnrichedMarkdownTextInput`** is an imperative [WYSIWYG](https://en.wikipedia.org/wiki/WYSIWYG) editor - the user sees formatted text, not raw markup - that turns their edits into a Markdown string. Toggling bold on a selection wraps it in `**...**`; making a line a heading prepends `#`. You read the result through `onChangeMarkdown`.
- **`EnrichedMarkdownText`** does the reverse: it parses a Markdown string from the `markdown` prop and renders native, styled text.

Because both speak the same format, a string produced by the editor renders identically in the display. That round-trip - edit, serialize to Markdown, store, render - is the core workflow the rest of these docs build on.

Next: see what's available and how to enable it in the [Feature support](/introduction/supported-features) overview.
