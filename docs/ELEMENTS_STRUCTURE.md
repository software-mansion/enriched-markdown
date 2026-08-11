# Element Structure

Markdown elements in `react-native-enriched-markdown` are organized into block and inline categories, each with distinct rendering behaviors.

## Supported Markdown Elements

`react-native-enriched-markdown` supports a comprehensive set of Markdown elements:

### Block Elements

| Element | Syntax | Style Property | Description |
|---------|--------|----------------|-------------|
| Headings | `# H1` to `###### H6` | `h1` - `h6` | Six levels of headings |
| Paragraphs | Plain text | `paragraph` | Default text container |
| Blockquotes | `> Quote` | `blockquote` | Quoted content with accent bar, unlimited nesting |
| Code Blocks | ` ``` code ``` ` | `codeBlock` | Multi-line code containers; with `flavor="github"` rendered as a block component with a language header and copy-code button |
| Unordered Lists | `- Item`, `* Item`, or `+ Item` | `list` | Bullet lists with unlimited nesting |
| Ordered Lists | `1. Item` | `list` | Numbered lists with unlimited nesting |
| Task Lists | `- [x] Done`, `- [ ] Todo` | `taskList` | Interactive checkboxes (requires `flavor="github"`) |
| Thematic Break | `---`, `***`, or `___` | `thematicBreak` | Horizontal rule separator |
| Images | `![alt](url)` | `image` | Block-level images with spacing |
| Tables | `| col | col |` | `table` | GFM tables with alignment support (requires `flavor="github"`) |
| Math Block | `$$...$$` | `math` | Block-level LaTeX math (display equations) (requires `flavor="github"`) |

### Inline Elements

| Element | Syntax | Style Property | Inherits From | Adds |
|---------|--------|----------------|---------------|------|
| Bold | `**text**` or `__text__` | `strong` | Parent block | Bold weight, optional color |
| Italic | `*text*` or `_text_` | `em` | Parent block | Italic style, optional color |
| Underline | `_text_` | `underline` | Parent block | Underline with custom color (iOS only; requires `md4cFlags`) |
| Strikethrough | `~~text~~` | `strikethrough` | Parent block | Strike line with custom color (iOS only) |
| Bold + Italic | `***text***`, `___text___`, etc. | `strong` + `em` | Parent block | Combined emphasis |
| Links | `[text](url)` | `link` | Parent block | Optional font family, color, underline |
| Inline Code | `` `code` `` | `code` | Parent block | Monospace font, background, optional fontSize |
| Inline Images | `![alt](url)` | `inlineImage` | N/A | Inline images within text flow |
| Inline Math | `$...$` | `inlineMath` | Parent block | LaTeX math rendered within the text flow |
| Spoiler | `\|\|text\|\|` | `spoiler` | Parent block | Text concealed behind animated particle overlay, tap to reveal. Can wrap inline text or entire blocks (e.g. a full paragraph) |
| Superscript | `^text^` | `superscript` | Parent block | Raised text at a reduced font size (requires `md4cFlags={{ superscript: true }}`) |
| Subscript | `~text~` | `subscript` | Parent block | Lowered text at a reduced font size (requires `md4cFlags={{ subscript: true }}`) |

> **Note:** Spoiler syntax (`||text||`) is always enabled. Any double-pipe delimiters in your content will be parsed as spoilers — for example, `a || b || c` would render `b` as a spoiler span rather than plain text.

> **Note:** Underscore syntax (`__text__`, `_text_`) works for bold/italic by default. Enable underline via `md4cFlags={{ underline: true }}` to treat `_text_` as underline instead of emphasis.

> **Note:** Enabling subscript (`md4cFlags={{ subscript: true }}`) changes the behaviour of single tildes — `~text~` becomes subscript instead of strikethrough. Double tildes (`~~text~~`) continue to work as strikethrough regardless.

### Nested Lists Example

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

### Lists with Block Content Example

List items can contain block elements — fenced code blocks, nested lists, and multiple paragraphs:

````markdown
1. Install via npm:

   ```
   npm install
   ```

2. Verify the connection.
````

Code blocks indent to the item's content column, and the marker is drawn next to the first line even when a code block or nested list is the item's first child.

### Nested Blockquotes Example

```markdown
> Level 1 quote
> > Level 2 nested
> > > Level 3 nested (unlimited depth!)
```

### Superscript and Subscript Examples

```markdown
E = mc^2^

H~2~O   H~2~SO~4~

^14^C dating  (isotope notation)

H~3~O^+^  (mixed superscript and subscript)
```

> Superscript and subscript can be nested inside other inline elements such as bold, italic, and links. They cannot be nested inside each other.

## Block vs Inline Elements

Markdown elements are divided into two categories:

### Block Elements

Block elements are structural containers that define the layout and establish their own typography context.

### Inline Elements

Inline elements modify text within blocks and apply additional styling on top of the block's typography.

## Line Breaks

Newlines follow standard CommonMark semantics by default:

- **Blank line**: Starts a new paragraph.
- **Single newline (soft break)**: Renders as a space — consecutive lines flow together into one wrapped paragraph, matching how GitHub and other CommonMark renderers display Markdown.
- **Hard break**: Ends a line with two spaces or a backslash to force a line break within the paragraph.

```markdown
This line and
this line render as one continuous sentence.

A blank line starts a new paragraph.

Two trailing spaces  
or a trailing backslash\
force a line break within the paragraph.
```

### Preserving single newlines

When displaying content authored in `EnrichedMarkdownTextInput`, pressing Enter produces a single newline in the serialized markdown. By default, `EnrichedMarkdownText` collapses these to spaces (per CommonMark). To preserve them as visible line breaks, enable the `hardSoftBreaks` flag:

```tsx
<EnrichedMarkdownText
  markdown={markdownFromInput}
  md4cFlags={{ hardSoftBreaks: true }}
/>
```

This forces the parser to treat every soft break as a hard break, so single newlines render as line breaks on all platforms.

## Images: Block vs Inline

Images are automatically detected as block or inline based on context:

- **Block images**: When an image is the only content in a paragraph (standalone), it's treated as a block image and uses block-level spacing
- **Inline images**: When an image appears alongside other text content, it's treated as inline and aligns with the text baseline

You don't need to specify which type—the renderer automatically determines this based on the image's position in the content. Note that a single newline doesn't split a paragraph, so an image on its own source line directly below text is still inline; separate it with a blank line to make it a block image.

## Nested Elements

Some elements support unlimited nesting depth with automatic indentation:

- **Blockquotes**: Each level adds a new accent bar
- **Unordered Lists**: Each level indents with `marginLeft`
- **Ordered Lists**: Each level indents and maintains separate numbering
