---
sidebar_label: Markdown flavors
sidebar_position: 0
---

import FlagsSrc from '!!raw-loader!@site/src/examples/react-native/rich-text-formatting/markdown-flavors/Flags';

# Markdown flavors

This section covers the rich text features layered on top of the CommonMark core introduced in [Core concepts](/introduction/core-concepts) - tables and task lists, LaTeX math, code-block highlighting, mentions, and streaming. Some are gated behind a **Markdown flavor**, others are toggled through `md4cFlags`, and a few are always on - so this page explains flavors first (the main switch) before you dive into the individual features.

## Why there are flavors

[CommonMark](https://commonmark.org/) is the strict, unambiguous specification for Markdown's core: headings, emphasis, lists, links, blockquotes, code. It deliberately leaves out everything that isn't universal, so different tools have historically layered their own **extensions** on top - tables, task lists, strikethrough, and more.

The most widely used of these supersets is **GitHub Flavored Markdown (GFM)**: CommonMark plus a well-defined set of extensions. Enriched Markdown lets you choose which dialect the parser uses so you only pay for the features you actually want.

## The `flavor` prop

`EnrichedMarkdownText` takes a `flavor` prop that selects the dialect:

- **`commonmark`** (default) - the core syntax only.
- **`github`** - CommonMark plus the GFM extensions.

<CodeTabs groupId="platform">
<Tab label="React Native">

```tsx
<EnrichedMarkdownText flavor="github" markdown={markdown} />
```

</Tab>
<Tab label="iOS"><ComingSoon platform="iOS" /></Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>

## What GFM adds

Setting `flavor="github"` turns on these extensions at parse time:

| Feature | Syntax |
|---|---|
| **Tables** | `\| col \| col \|`<br />`\| --- \| --- \|` |
| **Task lists** | `- [x] done`, `- [ ] todo` |
| **Strikethrough** | `~~text~~` |

In `commonmark` these stay literal - `~~text~~` renders as tildes and a `| a | b |` line is just text. Tables render with column alignment, rich text in cells, and header styling; task lists become interactive checkboxes you can respond to.

:::note
Bare-URL autolinking and spoilers (`||text||`) are always on, independent of the flavor. LaTeX math is on by default too, but it is controlled by the `latexMath` md4c flag rather than the flavor - though block math (`$$...$$`) only renders as a standalone equation with `flavor="github"`. See [LaTeX math](/rich-text-formatting/latex-math).
:::

## More than extensions: how the flavor renders

The flavor does more than toggle syntax - it also decides how the document is laid out natively, which is often the bigger practical difference between the two.

- **`commonmark` renders the whole document as one native text view** (a single attributed string). Because everything lives in one text run, selection and copy flow naturally across the entire document and the view stays lightweight. The trade-off is that block structures that can't be expressed inside a single text run - real tables, fenced code blocks with a header bar and copy button, display equations - are not rendered as such.
- **`github` splits the document into segments**, rendering each block as its own native view. That is what makes the richer block components possible: tables with column alignment, block-style code blocks (header, language label, copy button), display math, and block-level callbacks (reacting to a task-list checkbox toggle or a code-block copy). The trade-off is that a text selection is confined to a single segment - it cannot span two blocks - and selection offsets in menu callbacks are relative to the segment rather than the whole string.

As a rule of thumb, reach for `commonmark` when the content is mostly prose and seamless selection matters most, and `github` when you need tables, rich code blocks, or block-level interactions.

## Beyond flavors: individual parser extensions

A second set of inline extensions is toggled independently of the flavor, through the `md4cFlags` prop. Each is opt-in per feature rather than bundled into a dialect:

- `underline` - `_text_`
- `superscript` - `^text^`
- `subscript` - `~text~`
- `highlight` - `==text==`

<CodeTabs groupId="platform">
<Tab label="React Native">

<LivePreview src={FlagsSrc} />

</Tab>
<Tab label="iOS"><ComingSoon platform="iOS" /></Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>

The flag set also carries `latexMath` (on by default) and the newline options `hardSoftBreaks` and `preserveBlankLines`. See your platform's reference for what each flag enables and how to set it.

## The parsing model

Putting it together, three layers decide which syntax the parser recognizes:

1. **CommonMark core** - always parsed: headings, emphasis, lists, links, blockquotes, code, and images (everything in [Core concepts](/introduction/core-concepts)), plus two always-on extras: bare-URL autolinks and spoilers.
2. **The flavor** - `flavor="github"` adds the GFM extensions above (tables, task lists, strikethrough); `flavor="commonmark"` leaves them off.
3. **`md4cFlags`** - layer extra inline extensions on top of either flavor (underline, superscript, subscript, highlight) and tune math and newline handling (`latexMath`, `hardSoftBreaks`, `preserveBlankLines`).

For a given `(flavor, md4cFlags)` pair the same string always parses the same way on every platform - those are the only inputs that change which syntax is recognized.

## Enabling each feature

Mapping the rest of this section back to the three layers above - what each feature needs to be switched on:

- **Tables, task lists, strikethrough** - the GFM extensions covered above; `flavor="github"`.
- [**LaTeX math**](/rich-text-formatting/latex-math) - the `latexMath` flag (on by default); block equations also need `flavor="github"`.
- [**Editor-style text**](/rich-text-formatting/editor-style-text) - the `hardSoftBreaks` and `preserveBlankLines` flags.
- [**Code-block highlighting**](/rich-text-formatting/code-highlighting) - automatic for language-tagged fenced blocks (native only, independent of flavor).
- [**Mentions**](/rich-text-formatting/mentions) - not a parser feature at all; ordinary links with custom URL schemes.
- [**Markdown streaming**](/rich-text-formatting/markdown-streaming) - incremental rendering as tokens arrive.
