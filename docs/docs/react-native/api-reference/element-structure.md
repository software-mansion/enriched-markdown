---
sidebar_label: Element structure
sidebar_position: 4
---

import InteractiveExample from '@site/src/components/InteractiveExample';
import FirstText from '@site/src/examples/react-native/basics/your-first-project/FirstText';
import FirstTextSrc from '!!raw-loader!@site/src/examples/react-native/basics/your-first-project/FirstText';

# Element structure

This page is the **catalog of every Markdown element** `react-native-enriched-markdown` renders: what exists, whether it is a block or an inline element, and how elements nest. It is the map that ties the rest of the reference together:

- For the **syntax** of each element (how you write it), see [Core concepts](/introduction/core-concepts).
- For **styling** each element through `markdownStyle`, see [Style properties](/react-native/api-reference/style-properties).
- For **which platforms** support each element (iOS, Android, React Native, Web), see [Feature support](/introduction/supported-features).

The syntax and style-property columns below are pointers for scanning - follow the links above for the full detail.

## Block vs. inline elements

Every element falls into one of two categories, and the distinction drives how it lays out and how it inherits typography:

- **Block elements** are structural containers. They occupy whole lines, stack vertically, and each establishes its own typography context (font size, line height, spacing).
- **Inline elements** live _within_ a block and style a run of text. They inherit the containing block's typography and layer additional styling on top - bold text inside a heading takes the heading's size and adds weight.

## Supported elements

### Block elements

| Element | Syntax | Style property | Description |
|---------|--------|----------------|-------------|
| Headings | `# H1` to<br />`###### H6` | `h1` - `h6` | Six levels of headings |
| Paragraphs | Plain text | `paragraph` | Default text container |
| Blockquotes | `> Quote` | `blockquote` | Quoted content with accent bar, unlimited nesting |
| Admonitions | `> [!NOTE]` | `blockquote.admonitions` | GitHub alert callouts with an icon and title header (requires [`flavor="github"`](/react-native/api-reference/enriched-markdown-text#flavor)) |
| Code blocks | ` ``` code ``` ` | `codeBlock` | Multi-line code containers; with [`flavor="github"`](/react-native/api-reference/enriched-markdown-text#flavor) rendered as a block component with a language header and copy-code button |
| Unordered lists | `- Item`,<br />`* Item`, or<br />`+ Item` | `list` | Bullet lists with unlimited nesting |
| Ordered lists | `1. Item` | `list` | Numbered lists with unlimited nesting |
| Task lists | `- [x] Done`,<br />`- [ ] Todo` | `taskList` | Interactive checkboxes (requires [`flavor="github"`](/react-native/api-reference/enriched-markdown-text#flavor)) |
| Thematic break | `---`, `***`,<br />or `___` | `thematicBreak` | Horizontal rule separator |
| Images | `![alt](url)` | `image` | Block-level images with spacing |
| Videos | `<video src="url" />` | `video` | Native video player (requires [`flavor="github"`](/react-native/api-reference/enriched-markdown-text#flavor)) |
| Tables | `\| col \| col \|` | `table` | GFM tables with alignment support (requires [`flavor="github"`](/react-native/api-reference/enriched-markdown-text#flavor)) |
| Math block | `$$...$$` | `math` | Block-level LaTeX math (display equations) (requires [`flavor="github"`](/react-native/api-reference/enriched-markdown-text#flavor)) |

### Inline elements

Inline elements inherit the typography of their parent block and add their own styling on top. For how inheritance resolves and the base block style, see [Style inheritance](/react-native/api-reference/style-properties#style-inheritance).

| Element | Syntax | Style property | Adds |
|---------|--------|----------------|------|
| Bold | `**text**` (or `__text__`) | `strong` | Bold weight, optional color |
| Italic | `*text*` (or `_text_`) | `em` | Italic style, optional color |
| Underline | `_text_` | `underline` | Underline; custom underline color is iOS only (requires [`md4cFlags={{ underline: true }}`](/react-native/api-reference/enriched-markdown-text#underline)) |
| Strikethrough | `~~text~~` | `strikethrough` | Strike line; custom line color is iOS only |
| Bold + italic | `***text***` (or `___text___`) | `strong` + `em` | Combined emphasis |
| Links | `[text](url)` | `link` | Optional font family, color, underline |
| Inline code | `` `code` `` | `code` | Monospace font, background, optional fontSize |
| Inline images | `![alt](url)` | `inlineImage` | Inline images within the text flow (does not inherit block typography) |
| Inline math | `$...$` | `inlineMath` | LaTeX math rendered within the text flow |
| Spoiler | `\|\|text\|\|` | `spoiler` | Text concealed behind an animated particle overlay, tap to reveal. Can wrap inline text or an entire block (e.g. a full paragraph) |
| Superscript | `^text^` | `superscript` | Raised text at a reduced font size (requires [`md4cFlags={{ superscript: true }}`](/react-native/api-reference/enriched-markdown-text#superscript)) |
| Subscript | `~text~` | `subscript` | Lowered text at a reduced font size (requires [`md4cFlags={{ subscript: true }}`](/react-native/api-reference/enriched-markdown-text#subscript)) |
| Highlight | `==text==` | `highlight` | Highlighted text with a background color (requires [`md4cFlags={{ highlight: true }}`](/react-native/api-reference/enriched-markdown-text#highlight)) |

:::note
Some delimiters are ambiguous, and how they parse depends on your [`md4cFlags`](/react-native/api-reference/enriched-markdown-text#md4cflags):

- **Underscores** (`__text__`, `_text_`) mean bold/italic by default. Enable [`md4cFlags={{ underline: true }}`](/react-native/api-reference/enriched-markdown-text#underline) to treat `_text_` as underline instead.
- **Single tildes** (`~text~`) mean strikethrough by default. Enable [`md4cFlags={{ subscript: true }}`](/react-native/api-reference/enriched-markdown-text#subscript) to treat them as subscript instead - double tildes (`~~text~~`) stay strikethrough regardless.
- **Double pipes** (`||text||`) are always parsed as spoilers, so `a || b || c` renders `b` as a spoiler span rather than plain text.
:::

## Nesting

Several block elements support unlimited nesting depth with automatic indentation:

- **Blockquotes** - each level adds a new accent bar.
- **Unordered lists** - each level indents with `marginLeft`.
- **Ordered lists** - each level indents and maintains separate numbering.

### Nested lists

Indent a list item to nest it under the one above. Unordered and ordered lists can be nested to any depth, and each level is indented automatically:

```markdown
- First level
  - Second level
    - Third level
      - Fourth level (unlimited depth!)

1. First item
   1. Nested numbered
      1. Deep nested
   2. Another nested
2. Second item
```

### Lists with block content

List items can contain block elements - fenced code blocks, nested lists, and multiple paragraphs:

````markdown
1. Install via npm:

   ```
   npm install
   ```

2. Verify the connection.
````

Code blocks indent to the item's content column, and the marker is drawn next to the first line even when a code block or nested list is the item's first child.

### Nested blockquotes

Add a `>` for each level of quoting. Every level draws its own accent bar, and a blockquote can hold any other Markdown - paragraphs, lists, or deeper quotes:

```markdown
> Level 1 quote
> > Level 2 nested
> > > Level 3 nested (unlimited depth!)
```

:::note
The two flavors render blockquotes differently. Under [`flavor="github"`](/react-native/api-reference/enriched-markdown-text#flavor) a blockquote is a recursive **container block**: it draws its own box (padding on all sides, `borderRadius`, `backgroundColor`, and the accent border) and splits its content into segments, so a code block, table, or math block inside becomes a real nested block and each nesting level is its own box. Long-pressing one opens the copy menu. Under `flavor="commonmark"` blockquotes stay inside the single text view and are drawn with spans.
:::

### Superscript and subscript

Superscript raises text and subscript lowers it, both at a reduced font size - useful for exponents, footnote markers, and chemical formulas:

```markdown
E = mc^2^

H~2~O   H~2~SO~4~

^14^C dating  (isotope notation)

H~3~O^+^  (mixed superscript and subscript)
```

:::note
Superscript and subscript can be nested inside other inline elements such as bold, italic, and links. They cannot be nested inside each other.
:::

## Admonitions

With [`flavor="github"`](/react-native/api-reference/enriched-markdown-text#flavor), a blockquote whose first line is an alert marker renders as a themed callout with an icon and a title header instead of a plain quote:

```markdown
> [!NOTE]
> Useful information the reader should know.

> [!TIP]
> A helpful hint.

> [!IMPORTANT]
> Something essential to completing the task.

> [!WARNING]
> Urgent information needing immediate attention.

> [!CAUTION]
> Risks or negative outcomes of an action.
```

Those five markers are the whole set, and they are case-insensitive - `> [!note]` works the same as `> [!NOTE]`. A marker that is not one of the five is not an admonition: the block renders as an ordinary blockquote with the marker left in as literal text.

An admonition is still a blockquote, so it holds any block content - more paragraphs, lists, code blocks, even a video:

```markdown
> [!WARNING]
> Check these before upgrading:
>
> - the peer dependency range
> - your `enriched-markdown` config block
```

Admonitions reuse the blockquote's geometry and override only its colors, so they are styled through [`markdownStyle.blockquote.admonitions`](/react-native/api-reference/style-properties#admonitions) - one color pair per type, on top of the `blockquote` box itself.

:::note
Requires both [`flavor="github"`](/react-native/api-reference/enriched-markdown-text#flavor) and the [`md4cFlags.admonitions`](/react-native/api-reference/enriched-markdown-text#admonitions) flag. The flag is on by default, but it is forced off under `flavor="commonmark"`, where `> [!NOTE]` renders as a plain blockquote with the marker as text.
:::

## Images: block vs. inline

Images are automatically detected as block or inline based on context:

- **Block images** - when an image is the only content in a paragraph (standalone), it is treated as a block image and uses block-level spacing.
- **Inline images** - when an image appears alongside other text content, it is treated as inline and aligns with the text baseline.

You don't need to specify which type - the renderer determines it from the image's position in the content. Note that a single newline does not split a paragraph, so an image on its own source line directly below text is still inline; separate it with a blank line to make it a block image.

:::important
CommonMark has no block image. [`![alt](url)`](https://spec.commonmark.org/0.31.2/#images) is defined as an **inline** element wherever it appears, and the Supported elements table above lists "Block image" as a block only to describe what this renderer does with it.

The split is a rendering decision, not a parsing one: the parser emits the same inline image node in both cases, and the renderer flags the one that stands alone in its paragraph. Anything reading the AST - your own traversal, or another CommonMark implementation - sees an inline image either way.
:::

## Videos

Videos are embedded with an HTML `<video>` tag - the tag is the one piece of HTML the parser allowlists, and it is recognized only as a block-level element:

```markdown
<video src="https://example.com/ocean.mp4" />
```

The paired form `<video src="url"></video>` works identically. Only `src` is read: `width`, `height`, `controls`, `autoplay` and every other attribute are ignored, so all appearance comes from [`markdownStyle.video`](/react-native/api-reference/style-properties#video-specific). Playback controls come from the platform player - `AVPlayerViewController` on iOS, ExoPlayer on Android.

:::important
Quote the URL. An unquoted `src` ends at the first `/`, so `<video src=https://example.com/a.mp4 />` parses as the URL `https:` and nothing loads.
:::

:::note
Requires [`flavor="github"`](/react-native/api-reference/enriched-markdown-text#flavor) and the `enableVideo` build flag (on by default) - see [Optional native features](/react-native/guides/native-assets#optional-features). No other HTML is rendered: inline HTML is disabled and any other tag is ignored.
:::

A video inside a blockquote or an admonition renders normally. A video inside a **list item** is different: it is promoted out of the list and rendered as a standalone block above the remaining items, without a bullet or number. This may change in a future release.

:::caution
Videos are not supported on the web build yet - the tag renders as nothing there.
:::

## Line breaks

Newlines follow standard CommonMark semantics by default:

- **Blank line** - starts a new paragraph.
- **Single newline (soft break)** - renders as a space; consecutive lines flow together into one wrapped paragraph, matching how GitHub and other CommonMark renderers display Markdown.
- **Hard break** - end a line with two spaces or a backslash to force a line break within the paragraph.
- **`<br>`** - not supported. Raw HTML is disabled, so an inline `<br>` stays in the output as literal text and one on its own line is dropped. Use a hard break, or [`hardSoftBreaks`](/react-native/api-reference/enriched-markdown-text#hardsoftbreaks) below, instead.

```markdown
This line and
this line render as one continuous sentence.

A blank line starts a new paragraph.

Two trailing spaces  
or a trailing backslash\
force a line break within the paragraph.
```

### Preserving single newlines

When displaying content authored in `EnrichedMarkdownTextInput`, pressing Enter produces a single newline in the serialized markdown. By default, `EnrichedMarkdownText` collapses these to spaces (per CommonMark). To preserve them as visible line breaks, enable the [`hardSoftBreaks`](/react-native/api-reference/enriched-markdown-text#hardsoftbreaks) flag:

```tsx
<EnrichedMarkdownText
  markdown={markdownFromInput}
  md4cFlags={{ hardSoftBreaks: true }}
/>
```

This forces the parser to treat every soft break as a hard break, so single newlines render as line breaks on all platforms.

### Blank lines

By default, CommonMark collapses any run of consecutive blank lines between two blocks into a single paragraph break, so pressing Enter several times renders the same as pressing it once. To keep the extra spacing, enable the [`preserveBlankLines`](/react-native/api-reference/enriched-markdown-text#preserveblanklines) flag:

```tsx
<EnrichedMarkdownText
  markdown={markdownFromInput}
  markdownStyle={{ paragraph: { marginTop: 0, marginBottom: 0 } }}
  md4cFlags={{ preserveBlankLines: true }}
/>
```

Each blank line in the source renders as one empty line, so the output keeps the exact number of blank lines that were typed - four blank lines between two paragraphs render as four empty lines. This makes `EnrichedMarkdownText` reproduce content authored in `EnrichedMarkdownTextInput` line for line, which is useful for chat-style apps.

:::note
Paragraph margins stack on top of the blank-line spacing. Set `paragraph.marginTop` and `paragraph.marginBottom` to `0` in `markdownStyle` so that spacing is driven purely by blank lines; otherwise even a standard single-blank-line paragraph break will render with extra height.
:::

:::tip
To reproduce editor content line for line, combine `preserveBlankLines` with `hardSoftBreaks`. See the [Editor-style text](/rich-text-formatting/editor-style-text) guide for the full recipe.
:::

## Try it yourself

<InteractiveExample src={FirstTextSrc} component={FirstText} />
