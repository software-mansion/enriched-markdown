---
sidebar_label: Element structure
sidebar_position: 4
---

# Element structure

This page is about **what the renderer does with your Markdown**: which constructs it understands, how they nest, and where the result differs from what the source looks like. For the properties that control their appearance, see [Style properties](/ios/api-reference/style-properties).

## Block vs. inline elements

The renderer sorts every element into one of two kinds, and the distinction drives both styling and layout:

- **Block elements** occupy their own vertical space and carry their own font, color, and margins. A paragraph, a heading, a list, a quote, a code block.
- **Inline elements** live inside a line of text and modify a run of it. Bold, italic, links, inline code. They inherit size and line height from the block they sit in and override only what makes them distinct - see [Style inheritance](/ios/api-reference/style-properties#style-inheritance).

The whole document renders into a **single native text view**. Block structure is carried by attributes and paragraph styles, and the decorations that are not text - list bullets, checkboxes, quote bars, code block fills, spoiler overlays - are drawn around it. That is why a selection can run from the first heading to the last list item without interruption.

## Supported elements

### Block elements

| Element | Markdown | Notes |
| --- | --- | --- |
| Heading | `# H1` … `###### H6` | Six levels, each styled independently |
| Paragraph | Text separated by a blank line | |
| Blockquote | `> quoted` | Nests |
| Admonition | `> [!NOTE]` | Needs `MarkdownParsingOptions(admonitions: true)` - see [below](#admonitions) |
| Unordered list | `- item` | Nests |
| Ordered list | `1. item` | Nests |
| Task list | `- [ ]` / `- [x]` | Tappable - see [`.onTaskListItemToggle`](/ios/api-reference/enriched-markdown-text#ontasklistitemtoggle) |
| Table | GFM pipe table | Always enabled - see [below](#tables) |
| Fenced code block | ```` ```swift ```` | Language label is parsed; no syntax highlighting |
| Block image | `![alt](url)` alone in a paragraph | See [below](#images-block-vs-inline) |
| Thematic break | `---` | |
| Display math | `$$…$$` on its own line | Needs `EnrichedMarkdownLaTeX` - see [LaTeX math](/ios/guides/latex-math) |

### Inline elements

| Element | Markdown | Notes |
| --- | --- | --- |
| Strong | `**bold**` | |
| Emphasis | `*italic*` | |
| Underline | `_text_`, `__text__` | Needs `MarkdownParsingOptions(underline: true)`, and **replaces** the italic/bold meaning of those markers |
| Strikethrough | `~~struck~~` | Always enabled |
| Inline code | `` `code` `` | |
| Link | `[text](url)` | Tapping calls SwiftUI's [`openURL`](/ios/api-reference/enriched-markdown-text#openurl) action |
| Autolink | `<https://…>`, or a bare URL | Bare URLs, `www.` hosts, and emails need `permissiveAutolinks`, which is on by default |
| Inline image | `![alt](url)` beside text | See [below](#images-block-vs-inline) |
| Spoiler | `\|\|hidden\|\|` | Always enabled - see [below](#spoilers) |
| Superscript | `^text^` | Needs `MarkdownParsingOptions(superscript: true)` |
| Subscript | `~text~` | Needs `MarkdownParsingOptions(subscript: true)` |
| Highlight | `==text==` | Needs `MarkdownParsingOptions(highlight: true)` |
| Inline math | `$…$` | Needs `EnrichedMarkdownLaTeX` |

Tables, task lists, strikethrough, and spoilers have no option - they are always on. Everything else marked "needs" is a [parser extension](/ios/guides/parser-extensions).

## Nesting

### Nested lists

Indent a list item to nest it. Each level adds `List().marginLeading` of indent:

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

Paragraphs, quotes, code blocks, and admonitions all work as item content this way.

### Nested blockquotes

Stack `>` markers to nest quotes. Each level draws its own accent bar, so the depth is visible:

```markdown
> Outer quote
>
> > Inner quote
```

An admonition nested inside a quote - or inside another admonition - keeps its own title and its own tint while the outer bar stays where it is.

### Superscript and subscript

Both are inline, so they compose with the other inline styles and with each other's siblings:

```markdown
E = mc^2^ and H~2~O
```

They scale relative to the text around them rather than to a fixed size, which is why their style properties are unitless fractions - superscript inside an `h1` is larger than superscript in a paragraph, automatically.

## Admonitions

A blockquote whose **first line** is one of the five GitHub alert markers renders as a themed callout: the usual quote geometry plus a header row with a tinted icon and a bold title.

```markdown
> [!WARNING]
> This action cannot be undone.
```

The five types are `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, and `[!CAUTION]`. Colors come from the [`Admonition()`](/ios/api-reference/style-properties#admonition) element, and the geometry from [`Blockquote()`](/ios/api-reference/style-properties#blockquote).

This is an opt-in parser extension. Without `MarkdownParsingOptions(admonitions: true)` the marker stays **literal text** inside an ordinary quote.

A callout keeps working where you would expect it to: inside a list item it still draws its title and its own bar, indented to the item's text column. Copying one reproduces its `> [!NOTE]` marker, and VoiceOver announces the title as its own element ahead of the body.

## Tables

GFM pipe tables render as live views inside the text rather than as monospaced ASCII:

```markdown
| Package | Platform |
| --- | :-: |
| EnrichedMarkdown | iOS |
```

- Columns size to their content, and a long cell wraps rather than pushing the table wider.
- A table wider than the view **scrolls horizontally in place**, without moving the rest of the document.
- Cells take inline styling - bold, italic, inline code, strikethrough, and tappable links.
- Alignment comes from the separator row (`:--`, `:-:`, `--:`); [`Table().alignment(_:)`](/ios/api-reference/style-properties#table) sets the default for columns that do not specify one.

Long-pressing a table offers **Copy** (tab-separated text) and **Copy as Markdown** (the pipe table rebuilt with alignment separators and inline markers). To a text selection the whole table counts as a single character, so a selection that spans one copies it as tab-separated text in the plain flavor and as a real `<table>` in the HTML flavor. VoiceOver reads one element per row.

## Spoilers

`||text||` renders transparent under an overlay and shows when tapped. There is no option - spoiler syntax is always parsed. The overlay's shape is [`.markdownSpoilerOverlay`](/ios/api-reference/enriched-markdown-text#markdownspoileroverlay) and its colors are the [`Spoiler()`](/ios/api-reference/style-properties#spoiler) element.

```markdown
The killer was ||the butler||.
```

One spoiler reveals at a time, and a link inside a concealed one is not a link until it is revealed.

## Images: block vs. inline

The same `![alt](url)` syntax renders two different ways, and which one you get depends on **what else is in the paragraph**:

- **Block image** - the image is the only thing in its paragraph. It is laid out on its own, at `BlockImage().height`, spanning the container width.
- **Inline image** - anything else shares the line with it. It is drawn in the text flow at `InlineImage().size`, sized to sit on the line like a large glyph.

```markdown
![A block image](https://example.com/hero.png)

Some text with an ![inline image](https://example.com/icon.png) in it.
```

So putting an image on its own line is the whole gesture - there is no separate syntax to learn. Far more sources than `http(s)` work, and remote images are cached; see [Images and caching](/ios/guides/image-caching).

## Line breaks

By default Markdown **reflows** text: a single newline inside a paragraph is treated as a space, and consecutive blank lines collapse into one paragraph separator. Two parser options change that.

### Preserving single newlines

`MarkdownParsingOptions(hardSoftBreaks: true)` turns every single newline into a real line break, so the lines you typed are the lines you get:

```markdown
Roses are red
Violets are blue
```

Without it that renders as one line. With it, two. This is the option to reach for when you render user-authored text - chat messages, notes - where people expect Return to mean Return.

### Blank lines

`MarkdownParsingOptions(preserveBlankLines: true)` keeps consecutive blank lines instead of collapsing them, so deliberate vertical whitespace in the source survives into the output.

Both are off by default, and both are set per view through [`options`](/ios/api-reference/enriched-markdown-text#options).

## Writing direction

Paragraph text resolves its own base direction from the **first strong character**, the way any native text view does, so a document that mixes Arabic or Hebrew with Latin lays each paragraph out correctly with nothing to configure. There is no writing-direction modifier.

The decorations drawn around the text - list bullets and numbers, task checkboxes, blockquote and admonition bars - currently mirror with the **app's** layout direction rather than per paragraph, so an RTL paragraph in an LTR app keeps its markers on the left. Fenced code blocks are pinned left-to-right deliberately, so code reads as written. See [RTL support](/user-experience/rtl) for how right-to-left content behaves, and the [roadmap](/misc/roadmap#ios) for per-paragraph decorations.

## Raw HTML

HTML in the source is **not** rendered. An inline tag stays literal text - `<b>bold</b>` renders with its angle brackets - and an HTML block is parsed and dropped, producing nothing. There is no option to turn this on; use Markdown syntax, or the [theme](/ios/api-reference/markdown-theme) for anything Markdown cannot express.

## What is not rendered yet

| Element | Status |
| --- | --- |
| Code syntax highlighting | Not built into this package - see [Code highlighting](/rich-text-formatting/code-highlighting) |
| [Mentions](/rich-text-formatting/mentions) | No mention node or per-URL link variants |
| [Markdown streaming](/rich-text-formatting/markdown-streaming) | No public streaming API |
| Image tap callbacks, `maxHeight` / `aspectRatio` / `resizeMode` | Block images size by height and corner radius only |

:::note
Unlike a construct that is missing entirely, a node type with no renderer here still renders **its children**, so unsupported syntax loses its styling rather than its text. Nothing you write silently disappears from the document.
:::

See the [roadmap](/misc/roadmap#ios) for what is landing next.
