---
sidebar_label: Markdown flavors
sidebar_position: 0
---

# Markdown flavors

This section covers the rich text features layered on top of the CommonMark core introduced in [Core concepts](/introduction/core-concepts) — tables and task lists, LaTeX math, code-block highlighting, mentions, and streaming. Most of them are gated behind a **Markdown flavor**, so this page explains what flavors are and how to turn them on before you dive into the individual features.

## Why there are flavors

[CommonMark](https://commonmark.org/) is the strict, unambiguous specification for Markdown's core: headings, emphasis, lists, links, blockquotes, code. It deliberately leaves out everything that isn't universal, so different tools have historically layered their own **extensions** on top — tables, task lists, autolinked URLs, strikethrough, and more.

The most widely used of these supersets is **GitHub Flavored Markdown (GFM)**: CommonMark plus a well-defined set of extensions. Enriched Markdown lets you choose which dialect the parser uses so you only pay for the features you actually want.

## The `flavor` prop

`EnrichedMarkdownText` takes a `flavor` prop that selects the dialect:

- **`commonmark`** (default) — the core syntax only.
- **`github`** — CommonMark plus the GFM extensions.

```tsx
<EnrichedMarkdownText flavor="github" markdown={markdown} />
```

## What GFM adds

Setting `flavor="github"` unlocks:

| Feature | Syntax | Learn more |
|---|---|---|
| **Tables** | `\| col \| col \|` | [Element structure](/react-native/element-structure) |
| **Task lists** | `- [x] done`, `- [ ] todo` | [Element structure](/react-native/element-structure) |
| **Strikethrough** | `~~text~~` | [Element structure](/react-native/element-structure) |
| **Autolinked URLs** | bare `https://…` becomes a link | — |
| **Block & inline math** | `$$…$$`, `$…$` | [LaTeX math](/rich-text-formatting/latex-math) |

Tables render with column alignment, rich text in cells, and header styling; task lists become interactive checkboxes you can respond to. See the per-platform [`EnrichedMarkdownText`](/react-native/enriched-markdown-text) reference for the props that surface these.

## Beyond flavors: individual parser extensions

Some inline extensions are toggled independently of the flavor, through the `md4cFlags` prop — superscript (`^text^`), subscript (`~text~`), underline (`_text_`), and highlight (`==text==`). These are opt-in per feature rather than bundled into a flavor:

```tsx
<EnrichedMarkdownText
  markdown="E = mc^2^ and ==highlighted=="
  md4cFlags={{ superscript: true, highlight: true }}
/>
```

See [Element structure](/react-native/element-structure) for the full list of what each flag enables and how it interacts with the base syntax.

<!-- TODO: expand this into a full explanation of the parsing model — how the
flavor selects a base dialect, how md4cFlags layer extra inline extensions on
top, and what each concretely changes in the produced/consumed Markdown. -->

## In this section

- [Mentions](/rich-text-formatting/mentions) — @-mention flows with suggestion lists and custom styling.
- [LaTeX math](/rich-text-formatting/latex-math) — native rendering of block and inline equations.
- [Code-block highlighting](/rich-text-formatting/code-highlighting) — syntax highlighting for fenced code blocks.
- [Markdown streaming](/rich-text-formatting/markdown-streaming) — rendering Markdown incrementally as it arrives.
