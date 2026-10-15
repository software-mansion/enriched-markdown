---
sidebar_label: Parser extensions
sidebar_position: 0
---

# Parser extensions

Markdown is not one language. Beyond the [CommonMark](https://spec.commonmark.org/) core that every renderer agrees on, each flavor adds its own syntax, and this library lets you pick which of those additions are in play - per component, through the [`options`](/android/api-reference/enriched-markdown-text#options) parameter.

This guide is about what those options do and when to reach for them. For the bare list with types and defaults, see the [`EnrichedMarkdownText` reference](/android/api-reference/enriched-markdown-text#options).

## There is no flavor switch

There is no single setting that flips the parser between [CommonMark](https://spec.commonmark.org/) and [GitHub Flavored Markdown](https://github.github.com/gfm/). Instead:

- The **GitHub table, strikethrough, and task list** extensions are always on. There is nothing to enable and no way to turn them off - `~~struck~~` and `- [ ]` always mean what you expect.
- **Everything else** is an individual option you opt into.

So the question is never "which flavor am I in", only "is this particular piece of syntax enabled".

## The parsing model

Parsing happens in C++, in [md4c](https://github.com/mity/md4c), reached through JNI. The options you pass are translated into md4c's own feature flags before the document is parsed, which has two consequences worth internalizing:

**Options change parsing, not painting.** With an option off, its syntax is never recognized as syntax - the characters stay ordinary text. `^2^` with `superscript` off is a literal caret, two, caret. Nothing is hidden or stripped; it simply was never markup.

**Options are per component and change the parse.** Passing a new `MarkdownOptions` re-parses the document, so treat the value as part of your content rather than as a setting to toggle at speed:

```kotlin
EnrichedMarkdownText(
  markdown = content,
  options = MarkdownOptions(underline = true, admonitions = true),
)
```

Raw HTML is never parsed as HTML. `<b>bold</b>` in your source renders as literal text, on every option combination.

## The extensions

### Underline

`MarkdownOptions(underline = true)` **repurposes** the underscore markers: `_text_` and `__text__` render underlined instead of italic and bold.

This is a trade, not an addition. With the option on you can still write italic and bold - as `*text*` and `**text**` - but the underscore spellings stop meaning what they do everywhere else. Turn it on for content you control; be careful with user-authored Markdown, where people write `_italic_` and expect italics.

### Superscript and subscript

`MarkdownOptions(superscript = true)` renders `^text^` raised; `MarkdownOptions(subscript = true)` renders `~text~` lowered. They're independent options, and worth enabling together for anything with formulas or footnote markers - `E = mc^2^`, `H~2~O`.

One interaction to know: `subscript` claims a single tilde, while strikethrough uses two. `~x~` is a subscript and `~~x~~` is struck through, so the two coexist, but a lone tilde in prose stops being literal.

### Admonitions

`MarkdownOptions(admonitions = true)` turns the five GitHub alert blockquotes into themed callouts:

```markdown
> [!WARNING]
> This action cannot be undone.
```

Without the option, `[!WARNING]` is just the first line of an ordinary quote. Style the result through the [`admonitions`](/android/api-reference/style-properties#admonitions) block.

### Line break handling

Two options control how whitespace in the source survives into the output, and both matter most for **user-authored** text.

`MarkdownOptions(hardSoftBreaks = true)` makes every single newline a real line break. Markdown normally reflows lines within a paragraph, which surprises people writing chat messages or notes, where pressing Enter is expected to break the line.

`MarkdownOptions(preserveBlankLines = true)` keeps runs of blank lines instead of collapsing them, preserving deliberate vertical space.

### Permissive autolinks

`permissiveAutolinks` is the one extension that is **on** by default. It linkifies bare URLs, so `https://swmansion.com` becomes a link without being wrapped in `<>`. Turn it off if you need a stricter parse in which only explicit `[text](url)` links and `<bracketed>` autolinks are live.

## Math is not an option

There is no `latexMath` option. `$...$` and `$$...$$` parse as math only where `LatexMathPlugin`, from the `math` artifact, is enabled - through a `LatexMathPlugin { }` scope or `plugins = listOf(LatexMathPlugin)` - so math is never parsed with nothing to draw it. Without the plugin the `$` stays literal text.

## Reference

| Option | Default | Enables |
| --- | --- | --- |
| `permissiveAutolinks` | `true` | Bare URLs become links |
| `underline` | `false` | `_text_` / `__text__` render underlined |
| `superscript` | `false` | `^text^` renders raised |
| `subscript` | `false` | `~text~` renders lowered |
| `admonitions` | `false` | `> [!NOTE]` renders as a callout |
| `hardSoftBreaks` | `false` | A single newline is a line break |
| `preserveBlankLines` | `false` | Consecutive blank lines are kept |
| `highlight` | `false` | `==text==` renders with a highlight band |

Always on, with no option: tables, strikethrough, task lists. On with `LatexMathPlugin`: LaTeX math. Never on: raw HTML.
