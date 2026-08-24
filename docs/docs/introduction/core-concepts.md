---
sidebar_label: Core concepts
sidebar_position: 2
---

# Core concepts

In Enriched Markdown **Markdown is the shared format** between the two components. `EnrichedMarkdownTextInput` _produces_ Markdown as the user types, and `EnrichedMarkdownText` _consumes_ Markdown to render it. If you understand the Markdown syntax below, you understand what both components can express.

This page is a primer on that syntax and the flavor that decides which parts of it are available. It's platform-neutral - the same Markdown drives iOS, Android, and React Native.

## What is Markdown?

Markdown is a lightweight plain-text formatting syntax. You write ordinary text and add a few punctuation markers to convey structure — `**` around a word for **bold**, a leading `#` for a heading - and a parser turns that into styled, structured content.

It's the format behind README files, GitHub comments, chat apps, and note-taking tools. Its appeal is that the source stays readable as plain text: `**bold**` reads as "bold" even before it's rendered.

In this library the Markdown string is the thing you store, send over the wire, and feed back into a renderer - the styled output is derived from it.

## Markdown syntax

The examples below show the **raw Markdown** you write on the left, and describe what it renders to. This is the CommonMark core that every platform supports.

### Inline formatting

Inline formatting applies to a span of characters _inside_ a paragraph.

```md
**bold** and **also bold**
_italic_ and _also italic_
~~strikethrough~~
`inline code`
```

- `**text**` or `__text__` → **bold**
- `*text*` or `_text_` → _italic_
- `~~text~~` → ~~strikethrough~~
- `` `text` `` → `inline code`, rendered in a monospace font

You can combine them - for example `***bold italic***` applies bold and italic together.

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
In `EnrichedMarkdownText`, links are interactive - taps surface through the `onLinkPress` callback so you decide how to open them.
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

### Blockquotes

Prefix a line with `>` to quote it. Blockquotes can contain other Markdown and can be nested.

```md
> This is a quote.
>
> > And this is a quote inside a quote.
```

### Code blocks

Fence a block of code with triple backticks. An optional language after the opening fence enables syntax highlighting.

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

## Block vs. inline elements

Markdown elements fall into two families, and the distinction matters when you customize or combine them:

- **Block elements** occupy whole lines and stack vertically: headings, paragraphs, lists, blockquotes, code blocks, tables. They establish structure.
- **Inline elements** live _within_ a block and style a run of text: bold, italic, strikethrough, inline code, links.

Inline elements inherit typography from the block that contains them - bold text inside a heading takes the heading's size. For the full breakdown of which elements exist, how they nest, and how inheritance works, see the per-platform **Element structure** reference.

## Markdown flavors

There is a small CommonMark core that every Markdown parser agrees on (everything above), plus optional extensions layered on top. Enriched Markdown exposes this through the `flavor` prop:

- **CommonMark** (default) — the standard core syntax.
- **GitHub Flavored Markdown (GFM)** — CommonMark plus **tables**, **task lists**, **strikethrough** and much more. Opt in with `flavor="github"`.

```tsx
<EnrichedMarkdownText flavor="github" markdown={markdown} />
```

Tables render with column alignment, rich text in cells, and header styling; task lists become interactive checkboxes you can respond to. See the per-platform `EnrichedMarkdownText` reference for the props that surface these.

For an in-depth look at why flavors exist, everything GFM adds, and how extensions are enabled, see [Markdown flavors](/rich-text-formatting/markdown-flavors) in Rich text formatting.

## How the components use Markdown

Bringing it back to the two components:

- **`EnrichedMarkdownTextInput`** turns the user's edits into a Markdown string. Toggling bold on a selection wraps it in `**…**`; making a line a heading prepends `#`. You read the result through `onChangeMarkdown`.
- **`EnrichedMarkdownText`** does the reverse: it parses a Markdown string from the `markdown` prop and renders native, styled text.

Because both speak the same format, a string produced by the editor renders identically in the display. That round-trip — edit, serialize to Markdown, store, render — is the core workflow the rest of these docs build on.

Next: see which elements each platform supports in [Supported features](/introduction/supported-features).
