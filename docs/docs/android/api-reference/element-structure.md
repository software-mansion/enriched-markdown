---
sidebar_label: Element structure
sidebar_position: 4
---

# Element structure

This page is about **what the renderer does with your Markdown**: which constructs it understands, how they nest, and where the result differs from what the source looks like. For the properties that control their appearance, see [Style properties](/android/api-reference/style-properties).

## Block & inline elements

The renderer sorts every element into one of two kinds, and the distinction drives both styling and layout:

- **Block elements** occupy their own vertical space and carry their own font, color, and margins. A paragraph, a heading, a list, a quote, a code block.
- **Inline elements** live inside a line of text and modify a run of it. Bold, italic, links, inline code. They inherit size and line height from the block they sit in and override only what makes them distinct - see [Style inheritance](/android/api-reference/style-properties#style-inheritance).

The document renders into native text views, with block structure drawn by spans rather than by separate views. It is split into **segments** only at top-level tables and, when the [LaTeX math plugin](/android/guides/latex-math) is installed, at display-math blocks: each of those gets its own view, and the text between them is one text view. A selection can run from a heading to the last list item without interruption, but it stops at a segment boundary - it cannot span a table or a display-math block.

### Block elements

| Element           | Markdown                             | Notes                                                                                                            |
| ----------------- | ------------------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| Heading           | `# H1` … `###### H6`                 | Six levels, each styled independently                                                                            |
| Paragraph         | Text separated by a blank line       |                                                                                                                  |
| Blockquote        | `> quoted`                           | Nests                                                                                                            |
| Admonition        | `> [!NOTE]`                          | Needs `Md4cFlags(admonitions = true)` - see [below](#admonitions)                                                |
| Unordered list    | `- item`                             | Nests                                                                                                            |
| Ordered list      | `1. item`                            | Nests                                                                                                            |
| Task list         | `- [ ]` / `- [x]`                    | Tappable - see [`onTaskListItemToggle`](/android/api-reference/enriched-markdown-text#ontasklistitemtoggle)      |
| Table             | GFM pipe table                       | Always enabled - see [below](#tables)                                                                            |
| Fenced code block | ` ```python `                        | Colored by the fence's language with the optional [`code-highlight`](/android/guides/code-highlighting) artifact |
| Block image       | `![alt](url)` at the start of a line | See [below](#images-block-vs-inline)                                                                             |
| Thematic break    | `---`                                |                                                                                                                  |

### Inline elements

| Element       | Markdown                     | Notes                                                                                                                                                                                                       |
| ------------- | ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Strong        | `**bold**`, `__bold__`       |                                                                                                                                                                                                             |
| Emphasis      | `*italic*`, `_italic_`       |                                                                                                                                                                                                             |
| Underline     | `_text_`, `__text__`         | Needs `Md4cFlags(underline = true)`, and **replaces** the italic/bold meaning of those markers                                                                                                              |
| Strikethrough | `~~struck~~`, `~struck~`     | A single `~` means subscript instead when `Md4cFlags(subscript = true)` is set                                                                                                                              |
| Inline code   | `` `code` ``                 |                                                                                                                                                                                                             |
| Link          | `[text](url)`                | Inert until you handle [`onLinkClick`](/android/api-reference/enriched-markdown-text#onlinkclick)                                                                                                           |
| Autolink      | `<https://…>`, or a bare URL | Bare URLs need `permissiveAutolinks`, which is on by default                                                                                                                                                |
| Inline image  | `![alt](url)` beside text    | See [below](#images-block-vs-inline)                                                                                                                                                                        |
| Superscript   | `^text^`                     | Needs `Md4cFlags(superscript = true)`                                                                                                                                                                       |
| Subscript     | `~text~`                     | Needs `Md4cFlags(subscript = true)`                                                                                                                                                                         |
| Highlight     | `==text==`                   | Needs `Md4cFlags(highlight = true)`                                                                                                                                                                         |
| Spoiler       | `\|\|text\|\|`               | Always parsed; hidden under an overlay until tapped - see [`spoilerOverlay`](/android/api-reference/enriched-markdown-text#spoileroverlay) and [`spoiler`](/android/api-reference/style-properties#spoiler) |
| LaTeX math    | `$x^2$`, `$$x^2$$`           | Needs `Md4cFlags(latexMath = true)`. Shows its source text, delimiters included, unless [`LatexMathPlugin`](/android/guides/latex-math) from the `math` artifact is installed                               |

Raw HTML is not rendered: inline HTML such as `<b>` stays literal text, and HTML blocks are dropped from the output.

:::important
The `_` markers are context-dependent. By default `_italic_` and `__bold__` mean the same as `*italic*` and `**bold**`, but `Md4cFlags(underline = true)` reinterprets both `_text_` and `__text__` as underline, so under that flag they no longer produce emphasis or strong. The asterisk markers `*` and `**` always mean emphasis and strong, whatever the flag.
:::

## Nesting

Some Markdown blocks are [_container blocks_](https://spec.commonmark.org/0.31.2/#container-blocks): lists and blockquotes can hold other blocks inside them.

### Nested lists

Indent a list item to nest it. Each level adds `list.marginStart` of indent, and unordered levels change their bullet shape so depth stays readable - a filled disc at the first level, a hollow circle at the second, and a square at the third and every level below:

```markdown
- First level
  - Second level
    - Third level
```

Ordered and unordered lists can nest inside each other freely.

### Lists with block content

A list item can hold more than one line. Indent the continuation to the item's text column and it stays part of that item:

```markdown
1. First step

   A second paragraph inside the same item.

2. Second step
```

Paragraphs, quotes, and code blocks all work as item content this way. Tables do not: a table inside a list item or a blockquote is **not rendered**. Keep tables at the top level of the document.

### Nested blockquotes

Stack `>` markers to nest quotes. Each level draws its own accent bar, so the depth is visible:

```markdown
> Outer quote
>
> > Inner quote
```

## Admonitions

A blockquote whose **first line** is one of the five GitHub alert markers renders as a themed callout: the usual quote geometry plus a header row with a tinted icon and a bold title.

```markdown
> [!WARNING]
> This action cannot be undone.
```

The five types are `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, and `[!CAUTION]`. Colors come from the [`admonitions`](/android/api-reference/style-properties#admonitions) style block, which sits inside `blockquote { admonitions { } }`.

This is an opt-in parser extension. Without `Md4cFlags(admonitions = true)` the marker stays **literal text** inside an ordinary quote.

Two behaviors worth knowing:

- **An admonition nested inside a list item falls back to a plain blockquote**, with no header. This is a known limitation.
- **A body-less quote renders nothing at all**, admonition or not - a header with no text beneath it is not worth the vertical space.

Copying a callout reproduces its `> [!NOTE]` marker, and TalkBack announces the header ahead of the body.

## Tables

GFM pipe tables render as real views inside the text rather than as monospaced ASCII, and need no flag - they are always parsed:

```markdown
| Package                   | Platform |
| ------------------------- | :------: |
| enriched-markdown-android | Android  |
```

- Each column sizes to its content, between 60dp and 300dp wide (plus cell padding). A cell longer than that wraps rather than pushing the column wider.
- A table wider than the view **scrolls horizontally in place**, without moving the rest of the document. `table { horizontalOverflow }` lets the scrolling table extend that far past the text column on each side, for example to reach the screen edge.
- Column alignment comes only from the separator row (`:--`, `:-:`, `--:`). `table { alignment }` is something else: it places a table that is narrower than the view at the start, center, or end of the line.
- A table is its own segment, so a selection cannot run across it, and a table nested inside a list item or blockquote is not rendered.
- Cells take inline styling - bold, italic, inline code, strikethrough, and tappable links.

Colors, borders, padding and the header row are all styled through the [`table`](/android/api-reference/style-properties#table) block.

## Images: block vs. inline

The same `![alt](url)` syntax renders two different ways, and which one you get depends on **where the image sits on its line**:

- **Block image** - the image is at the start of a line. It is laid out on its own, at `image.height`, spanning the container width. This holds even when text follows it on the same line.
- **Inline image** - text comes before it on the line. It is drawn in the text flow at `inlineImage.size`, sized to sit on the line like a large glyph.

Markdown itself has no block image syntax; this is purely how the renderer lays the image out.

```markdown
![A block image](https://example.com/hero.png)

Some text with an ![inline image](https://example.com/icon.png) in it.
```

So putting an image on its own line is the whole gesture - there is no separate syntax to learn. Remote images are downloaded and cached; see [Image caching](/android/guides/image-caching).

## Line breaks

By default Markdown **reflows** text: a single newline inside a paragraph is treated as a space, and consecutive blank lines collapse into one paragraph separator. Two parser flags change that.

### Preserving single newlines

`Md4cFlags(hardSoftBreaks = true)` turns every single newline into a real line break, so the lines you typed are the lines you get:

```markdown
Roses are red
Violets are blue
```

Without the flag that renders as one line. With it, two. This is the flag to reach for when you render user-authored text - chat messages, notes - where people expect Enter to mean Enter.

### Blank lines

`Md4cFlags(preserveBlankLines = true)` keeps consecutive blank lines instead of collapsing them, so deliberate vertical whitespace in the source survives into the output:

```text
A first paragraph.



A second one, three blank lines later.
```

Without the flag those three blank lines collapse to one paragraph break; with it, the gap is kept.

Both flags are off by default, and both are set per instance through [`flags`](/android/api-reference/enriched-markdown-text#flags).

## Spacing

Each block's `marginTop` and `marginBottom` add up: the gap between two blocks is the first one's `marginBottom` plus the next one's `marginTop`. The last block's `marginBottom` is trimmed, so the view ends at its content; pass [`includeLastBlockMargin = true`](/android/api-reference/enriched-markdown-text#includelastblockmargin) to keep it.
