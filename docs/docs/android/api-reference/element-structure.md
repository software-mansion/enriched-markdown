---
sidebar_label: Element structure
sidebar_position: 4
---

# Element structure

This page is about **what the renderer does with your Markdown**: which constructs it understands, how they nest, and where the result differs from what the source looks like. For the properties that control their appearance, see [Style properties](/android/api-reference/style-properties).

## Block vs. inline elements

The renderer sorts every element into one of two kinds, and the distinction drives both styling and layout:

- **Block elements** occupy their own vertical space and carry their own font, color, and margins. A paragraph, a heading, a list, a quote, a code block.
- **Inline elements** live inside a line of text and modify a run of it. Bold, italic, links, inline code. They inherit size and line height from the block they sit in and override only what makes them distinct - see [Style inheritance](/android/api-reference/style-properties#style-inheritance).

The whole document renders into a **single native text view**, with block structure drawn by spans rather than by separate views. That is why a selection can run from the first heading to the last list item without interruption.

## Supported elements

### Block elements

| Element | Markdown | Notes |
| --- | --- | --- |
| Heading | `# H1` … `###### H6` | Six levels, each styled independently |
| Paragraph | Text separated by a blank line | |
| Blockquote | `> quoted` | Nests |
| Admonition | `> [!NOTE]` | Needs `Md4cFlags(admonitions = true)` - see [below](#admonitions) |
| Unordered list | `- item` | Nests |
| Ordered list | `1. item` | Nests |
| Task list | `- [ ]` / `- [x]` | Tappable - see [`onTaskListItemPress`](/android/api-reference/enriched-markdown-text#ontasklistitempress) |
| Fenced code block | ```` ```kotlin ```` | Language label is parsed; no syntax highlighting |
| Block image | `![alt](url)` alone in a paragraph | See [below](#images-block-vs-inline) |
| Thematic break | `---` | |

### Inline elements

| Element | Markdown | Notes |
| --- | --- | --- |
| Strong | `**bold**` | |
| Emphasis | `*italic*` | |
| Underline | `_text_`, `__text__` | Needs `Md4cFlags(underline = true)`, and **replaces** the italic/bold meaning of those markers |
| Strikethrough | `~~struck~~` | |
| Inline code | `` `code` `` | |
| Link | `[text](url)` | Inert until you handle [`onLinkPress`](/android/api-reference/enriched-markdown-text#onlinkpress) |
| Autolink | `<https://…>`, or a bare URL | Bare URLs need `permissiveAutolinks`, which is on by default |
| Inline image | `![alt](url)` beside text | See [below](#images-block-vs-inline) |
| Superscript | `^text^` | Needs `Md4cFlags(superscript = true)` |
| Subscript | `~text~` | Needs `Md4cFlags(subscript = true)` |

## Nesting

### Nested lists

Indent a list item to nest it. Each level adds `list.marginLeft` of indent, and unordered levels alternate their bullet shape so depth stays readable:

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

Paragraphs, quotes, and code blocks all work as item content this way.

### Nested blockquotes

Stack `>` markers to nest quotes. Each level draws its own accent bar, so the depth is visible:

```markdown
> Outer quote
>
> > Inner quote
```

### Superscript and subscript

Both are inline, so they compose with other inline styles and with each other's siblings:

```markdown
E = mc^2^ and H~2~O
```

They scale relative to the text around them rather than to a fixed size, which is why their style properties are unitless fractions - superscript text inside an `h1` is larger than superscript text in a paragraph, automatically.

## Admonitions

A blockquote whose **first line** is one of the five GitHub alert markers renders as a themed callout: the usual quote geometry plus a header row with a tinted icon and a bold title.

```markdown
> [!WARNING]
> This action cannot be undone.
```

The five types are `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, and `[!CAUTION]`. Colors come from the [`admonitions`](/android/api-reference/style-properties#admonitions) style block.

This is an opt-in parser extension. Without `Md4cFlags(admonitions = true)` the marker stays **literal text** inside an ordinary quote.

Two behaviors worth knowing:

- **An admonition nested inside a list item falls back to a plain blockquote**, with no header. This is deliberate and consistent across every platform the library targets, so one document looks the same everywhere.
- **A body-less quote renders nothing at all**, admonition or not - a header with no text beneath it is not worth the vertical space.

Copying a callout reproduces its `> [!NOTE]` marker, and TalkBack announces the header ahead of the body.

## Images: block vs. inline

The same `![alt](url)` syntax renders two different ways, and which one you get depends on **what else is in the paragraph**:

- **Block image** - the image is the only thing in its paragraph. It is laid out on its own, at `image.height`, spanning the container width.
- **Inline image** - anything else shares the line with it. It is drawn in the text flow at `inlineImage.size`, sized to sit on the line like a large glyph.

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

`Md4cFlags(preserveBlankLines = true)` keeps consecutive blank lines instead of collapsing them, so deliberate vertical whitespace in the source survives into the output.

Both flags are off by default, and both are set per instance through [`flags`](/android/api-reference/enriched-markdown-text#flags).

## Not rendered yet

The parser understands more than the renderer draws. These constructs parse without error but produce no special rendering today:

| Element | Status |
| --- | --- |
| Tables | Renderer in progress |
| LaTeX math (inline and block) | Renderer in progress |
| Spoilers | Renderer in progress |
| Highlight (`==text==`) | No renderer |
| Code syntax highlighting | Not built into this package |

:::caution
A construct with no renderer has its text **dropped from the output** rather than shown unstyled, so enabling [`latexMath`](/android/api-reference/enriched-markdown-text#latexmath) or [`highlight`](/android/api-reference/enriched-markdown-text#highlight) makes that content vanish. Both flags are off by default; leave them off until the renderers land. Tables and spoilers have no flag to enable, so they are simply parsed and skipped.
:::

See the [roadmap](/misc/roadmap#android-renderer) for what is landing next.
