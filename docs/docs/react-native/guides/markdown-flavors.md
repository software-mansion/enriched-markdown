---
sidebar_label: Markdown flavors
sidebar_position: 0
---

import FlagsSrc from '!!raw-loader!@site/src/examples/react-native/guides/markdown-flavors/Flags';

# Markdown flavors

`EnrichedMarkdownText` parses more than the CommonMark core introduced in [Core concepts](/introduction/core-concepts): tables, task lists, LaTeX math, and extra inline syntax. Some of that is gated behind a **Markdown flavor**, some is toggled through `md4cFlags`, and a few pieces are always on. This guide explains the flavor first, because it is the main switch, and then the rest of the parsing model.

## Why there are flavors

[CommonMark](https://commonmark.org/) is the strict, unambiguous specification for Markdown's core: headings, emphasis, lists, links, blockquotes, code. It deliberately leaves out everything that isn't universal, so different tools have historically layered their own **extensions** on top - tables, task lists, strikethrough, and more.

The most widely used of these supersets is **GitHub Flavored Markdown ([GFM](https://github.github.com/gfm/))**: CommonMark plus a well-defined set of extensions. Enriched Markdown lets you choose which dialect the parser uses so you only pay for the features you actually want.

## The `flavor` prop

`EnrichedMarkdownText` takes a [`flavor`](/react-native/api-reference/enriched-markdown-text#flavor) prop that selects the dialect:

- **`commonmark`** (default) - the core syntax only.
- **`github`** - CommonMark plus the GFM extensions.

```tsx
<EnrichedMarkdownText flavor="github" markdown={markdown} />
```

## What GFM adds

This is the canonical list of everything `flavor="github"` changes. The other pages link here rather than repeating it.

**At parse time**, three extensions switch on:

| Feature | Syntax |
|---|---|
| **Tables** | `\| col \| col \|`<br />`\| --- \| --- \|` |
| **Task lists** | `- [x] done`, `- [ ] todo` |
| **Strikethrough** | `~~text~~` |

In `commonmark` these stay literal - `~~text~~` renders as tildes and a `| a | b |` line is just text. A fourth parser flag, [`admonitions`](/react-native/api-reference/enriched-markdown-text#admonitions), is on by default but **forced off** under `commonmark`, so `> [!NOTE]` is a GitHub-only callout in practice too.

**At render time**, `github` additionally unlocks:

| Feature | What you get |
|---|---|
| **Tables** | Column alignment, rich text in cells, header styling, horizontal scrolling |
| **Code blocks** | A block component with a header bar, language label and copy button, plus [`onCopyPress`](/react-native/api-reference/enriched-markdown-text#oncopypress) |
| **Block math** | `$$...$$` as a standalone, scrollable display equation rather than an inline attachment |
| **Videos** | The `<video>` player (the tag itself is parsed in both flavors) |
| **Blockquote containers** | Blockquotes and admonitions as real container views, with a block context menu |
| **Task list toggling** | Interactive checkboxes, reported through [`onTaskListItemPress`](/react-native/api-reference/enriched-markdown-text#ontasklistitempress) |

**And two things you give up** under `github`:

- [`numberOfLines`](/react-native/api-reference/enriched-markdown-text#numberoflines) and [`ellipsizeMode`](/react-native/api-reference/enriched-markdown-text#ellipsizemode) are ignored - independent block segments cannot honor a document-wide line cap.
- A text selection cannot span two segments, and the selection offsets handed to [`contextMenuItems`](/react-native/api-reference/enriched-markdown-text#contextmenuitems) are relative to the segment, not the whole string.

:::note
Bare-URL autolinking and spoilers (`||text||`) are always on, independent of the flavor, and `<video>` is promoted in both flavors even though only `github` renders a player. See [LaTeX math](/rich-text-formatting/latex-math) for the math details.
:::

## More than extensions: how the flavor renders

The flavor does more than toggle syntax - it also decides how the document is laid out in the native view tree, which is often the bigger practical difference between the two.

- **`commonmark` renders the whole document as one native text view** (a single attributed string). Because everything lives in one text run, selection and copy flow naturally across the entire document and the view stays lightweight. The trade-off is that block structures that can't be expressed inside a single text run - real tables, fenced code blocks with a header bar and copy button, display equations - are not rendered as such.
- **`github` splits the document into segments**, rendering each block as its own native view. That is what makes the richer block components possible: tables with column alignment, block-style code blocks (header, language label, copy button), display math, and block-level callbacks (reacting to a task-list checkbox toggle or a code-block copy). The trade-off is that a text selection is confined to a single segment - it cannot span two blocks - and the selection offsets handed to [`contextMenuItems`](/react-native/api-reference/enriched-markdown-text#contextmenuitems) are relative to the segment rather than the whole string.

As a rule of thumb, reach for `commonmark` when the content is mostly prose and seamless selection matters most, and `github` when you need tables, rich code blocks, or block-level interactions.

:::note
The prop has no effect on the web build, which always parses the GFM extensions - its renderer builds a DOM tree, so it has none of the single-text-run constraints that make the flavor meaningful on iOS and Android. See [Web support](/react-native/guides/web-support).
:::

## Beyond flavors: individual parser extensions

A second set of inline extensions is toggled independently of the flavor, through the [`md4cFlags`](/react-native/api-reference/enriched-markdown-text#md4cflags) prop. Each is opt-in per feature rather than bundled into a dialect:

- `underline` - `_text_`
- `superscript` - `^text^`
- `subscript` - `~text~`
- `highlight` - `==text==`

<LivePreview src={FlagsSrc} />

The flag set also carries `latexMath` and `admonitions` (both on by default) and the newline options `hardSoftBreaks` and `preserveBlankLines`. See the [`md4cFlags` reference](/react-native/api-reference/enriched-markdown-text#md4cflags) for what each flag enables and its default.

`admonitions` is the one flag gated by **both** layers: the flag must be on *and* the flavor must be `github`, because `commonmark` forces it off.

## The parsing model

Putting it together, three layers decide which syntax the parser recognizes:

1. **CommonMark core** - always parsed: headings, emphasis, lists, links, blockquotes, code, and images (everything in [Core concepts](/introduction/core-concepts)), plus two always-on extras: bare-URL autolinks and spoilers.
2. **The flavor** - `flavor="github"` adds the GFM extensions above (tables, task lists, strikethrough); `flavor="commonmark"` leaves them off.
3. **`md4cFlags`** - layer extra inline extensions on top of either flavor (underline, superscript, subscript, highlight) and tune math, admonitions and newline handling (`latexMath`, `admonitions`, `hardSoftBreaks`, `preserveBlankLines`). `admonitions` is the exception to "on top of either flavor": it is forced off under `commonmark`.

For a given `(flavor, md4cFlags)` pair the same string always parses the same way - those are the only inputs that change which syntax is recognized.

## Enabling each feature

Mapping the rich text features back to the three layers above - what each one needs to be switched on:

- **Tables, task lists, strikethrough** - the GFM extensions covered above; `flavor="github"`.
- **Admonitions** - the `admonitions` flag (on by default) **and** `flavor="github"`.
- [**LaTeX math**](/rich-text-formatting/latex-math) - the `latexMath` flag (on by default); block equations also need `flavor="github"`. Rendering additionally needs the native math engine, which the `enableMath` [build flag](/react-native/guides/native-assets#optional-features) includes by default.
- [**Editor-style text**](/rich-text-formatting/editor-style-text) - the `hardSoftBreaks` and `preserveBlankLines` flags.
- [**Code-block highlighting**](/rich-text-formatting/code-highlighting) - automatic for language-tagged fenced blocks, independent of the flavor, as long as the `enableCodeHighlight` [build flag](/react-native/guides/native-assets#optional-features) is on (it is by default). The header and copy button do need `flavor="github"`.
- [**Mentions**](/rich-text-formatting/mentions) - not a parser feature at all; ordinary links with custom URL schemes.
- [**Markdown streaming**](/rich-text-formatting/markdown-streaming) - the [`streamingAnimation`](/react-native/api-reference/enriched-markdown-text#streaminganimation) prop (off by default), tuned by [`streamingConfig`](/react-native/api-reference/enriched-markdown-text#streamingconfig), which itself needs `flavor="github"` to have any effect.

## Reference

- [`flavor`](/react-native/api-reference/enriched-markdown-text#flavor) - the dialect switch.
- [`md4cFlags`](/react-native/api-reference/enriched-markdown-text#md4cflags) - the individual parser extensions and their defaults.
- [Element structure](/react-native/api-reference/element-structure) - every supported element and which ones are GitHub-only.
- [Feature support](/introduction/supported-features) - the per-target matrix.
