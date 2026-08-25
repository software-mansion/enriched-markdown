---
sidebar_label: Element structure
sidebar_position: 4
---

# Element structure

:::caution
THIS PAGE IS WORK IN PROGRESS
:::

Markdown elements in `react-native-enriched-markdown` are organized into block and inline categories, each with distinct rendering behaviors.

## Supported Markdown elements

`react-native-enriched-markdown` supports a comprehensive set of Markdown elements.

### Block elements

| Element | Syntax | Style property | Description |
|---------|--------|----------------|-------------|
| Headings | `# H1` to `###### H6` | `h1` – `h6` | Six levels of headings |
| Paragraphs | Plain text | `paragraph` | Default text container |
| Blockquotes | `> Quote` | `blockquote` | Quoted content with accent bar, unlimited nesting |
| Code blocks | ` ``` code ``` ` | `codeBlock` | Multi-line code containers |
| Unordered lists | `- Item`, `* Item`, or `+ Item` | `list` | Bullet lists with unlimited nesting |
| Ordered lists | `1. Item` | `list` | Numbered lists with unlimited nesting |
| Task lists | `- [x] Done`, `- [ ] Todo` | `taskList` | Interactive checkboxes (requires `flavor="github"`) |
| Thematic break | `---`, `***`, or `___` | `thematicBreak` | Horizontal rule separator |
| Images | `![alt](url)` | `image` | Block-level images with spacing |
| Tables | `\| col \| col \|` | `table` | GFM tables with alignment support (requires `flavor="github"`) |
| Math block | `$$...$$` | `math` | Block-level LaTeX math (display equations) (requires `flavor="github"`) |

### Inline elements

| Element | Syntax | Style property | Inherits from | Adds |
|---------|--------|----------------|---------------|------|
| Bold | `**text**` or `__text__` | `strong` | Parent block | Bold weight, optional color |
| Italic | `*text*` or `_text_` | `em` | Parent block | Italic style, optional color |
| Underline | `_text_` | `underline` | Parent block | Underline with custom color (iOS only; requires `md4cFlags`) |
| Strikethrough | `~~text~~` | `strikethrough` | Parent block | Strike line with custom color (iOS only) |
| Bold + Italic | `***text***`, `___text___`, etc. | `strong` + `em` | Parent block | Combined emphasis |
| Links | `[text](url)` | `link` | Parent block | Optional font family, color, underline |
| Inline code | `` `code` `` | `code` | Parent block | Monospace font, background, optional fontSize |
| Inline images | `![alt](url)` | `inlineImage` | N/A | Inline images within text flow |
| Inline math | `$...$` | `inlineMath` | Parent block | LaTeX math rendered within the text flow |
| Spoiler | `\|\|text\|\|` | `spoiler` | Parent block | Text concealed behind an animated particle overlay, tap to reveal. Can wrap inline text or entire blocks (e.g. a full paragraph) |
| Superscript | `^text^` | `superscript` | Parent block | Raised text at a reduced font size (requires `md4cFlags={{ superscript: true }}`) |
| Subscript | `~text~` | `subscript` | Parent block | Lowered text at a reduced font size (requires `md4cFlags={{ subscript: true }}`) |

:::note
Spoiler syntax (`||text||`) is always enabled. Any double-pipe delimiters in your content will be parsed as spoilers — for example, `a || b || c` would render `b` as a spoiler span rather than plain text.
:::

:::note
Underscore syntax (`__text__`, `_text_`) works for bold/italic by default. Enable underline via `md4cFlags={{ underline: true }}` to treat `_text_` as underline instead of emphasis.
:::

:::note
Enabling subscript (`md4cFlags={{ subscript: true }}`) changes the behavior of single tildes — `~text~` becomes subscript instead of strikethrough. Double tildes (`~~text~~`) continue to work as strikethrough regardless.
:::

### Nested lists example

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

### Lists with block content example

List items can contain block elements — fenced code blocks, nested lists, and multiple paragraphs:

````markdown
1. Install via npm:

   ```
   npm install
   ```

2. Verify the connection.
````

Code blocks indent to the item's content column, and the marker is drawn next to the first line even when a code block or nested list is the item's first child.

### Nested blockquotes example

```markdown
> Level 1 quote
> > Level 2 nested
> > > Level 3 nested (unlimited depth!)
```

### Superscript and subscript examples

```markdown
E = mc^2^

H~2~O   H~2~SO~4~

^14^C dating  (isotope notation)

H~3~O^+^  (mixed superscript and subscript)
```

:::note
Superscript and subscript can be nested inside other inline elements such as bold, italic, and links. They cannot be nested inside each other.
:::

## Block vs. inline elements

Markdown elements are divided into two categories:

- **Block elements** are structural containers that define the layout and establish their own typography context.
- **Inline elements** modify text within blocks and apply additional styling on top of the block's typography.

## Images: block vs. inline

Images are automatically detected as block or inline based on context:

- **Block images** — when an image is the only content in a paragraph (standalone), it's treated as a block image and uses block-level spacing.
- **Inline images** — when an image appears alongside other text content, it's treated as inline and aligns with the text baseline.

You don't need to specify which type — the renderer automatically determines this based on the image's position in the content.

## Nested elements

Some elements support unlimited nesting depth with automatic indentation:

- **Blockquotes** — each level adds a new accent bar.
- **Unordered lists** — each level indents with `marginLeft`.
- **Ordered lists** — each level indents and maintains separate numbering.
