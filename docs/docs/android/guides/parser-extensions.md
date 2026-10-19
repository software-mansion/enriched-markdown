---
sidebar_label: Parser extensions
sidebar_position: 0
---

# Parser extensions

Markdown is not one language. Beyond the [CommonMark](https://spec.commonmark.org/) core that every renderer agrees on, each flavor adds its own syntax, and this library lets you pick which of those additions are in play - per component, through the [`options`](/android/api-reference/enriched-markdown-text#options) parameter.

This guide is about what those options do and when to reach for them. For the bare list with types and defaults, see the [`EnrichedMarkdownText` reference](/android/api-reference/enriched-markdown-text#options).

## There is no flavor switch

There is no single setting that flips the parser between [CommonMark](https://spec.commonmark.org/) and [GitHub Flavored Markdown](https://github.github.com/gfm/). Instead:

- The **GitHub table, strikethrough, and task list** extensions, and **spoilers**, are always on. There is nothing to enable and no way to turn them off - `~~struck~~`, `- [ ]` and `||hidden||` always mean what you expect.
- **Everything else** is an individual option you opt into.

:::caution
A table must sit at the top level of the document. A table nested inside a list item or a blockquote is **not rendered** - its content is missing from the page, not shown as text.
:::

So the question is never "which flavor am I in", only "is this particular piece of syntax enabled".

## The parsing model

Parsing happens in C++, in [md4c](https://github.com/mity/md4c), reached through JNI. The options you pass are translated into md4c's own feature flags before the document is parsed, which has two consequences worth internalizing:

**Options change parsing, not painting.** With an option off, its syntax is never recognized as syntax - the characters stay ordinary text. `^2^` with `superscript` off is a literal caret, two, caret. Nothing is hidden or stripped; it simply was never markup.

**Options are per component and change the parse.** Passing a *different* `MarkdownOptions` re-parses the document, so treat the value as part of your content rather than as a setting to toggle at speed. `MarkdownOptions` is a data class, so an **equal** value is a no-op - building it inline, as below, does not re-parse on every recomposition:

```kotlin
import androidx.compose.runtime.Composable
import com.swmansion.enriched.markdown.MarkdownOptions
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText

@Composable
fun Article(content: String) {
  EnrichedMarkdownText(
    markdown = content,
    options = MarkdownOptions(underline = true, admonitions = true),
  )
}
```

Raw HTML is never parsed as HTML, on every option combination, and what happens to it depends on where it sits:

- **Inline HTML** stays as literal text: `<b>bold</b>` in a sentence renders as those characters.
- **Block HTML** - a line that opens with a tag such as `<div>` or `<details>`, or with an `<!-- comment -->` - is **dropped**, together with everything up to the next blank line. It is not shown as text.

## The extensions

### Underline

`MarkdownOptions(underline = true)` **repurposes** the underscore markers: `_text_` and `__text__` render underlined instead of italic and bold.

This is a trade, not an addition. With the option on you can still write italic and bold - as `*text*` and `**text**` - but the underscore spellings stop meaning what they do everywhere else. Turn it on for content you control; be careful with user-authored Markdown, where people write `_italic_` and expect italics.

### Superscript and subscript

`MarkdownOptions(superscript = true)` renders `^text^` raised; `MarkdownOptions(subscript = true)` renders `~text~` lowered. They're independent options, and worth enabling together for anything with formulas or footnote markers - `E = mc^2^`, `H~2~O`.

One interaction to know: `subscript` **changes what a single tilde means**. Strikethrough is always on and accepts one tilde or two, so by default `~x~` and `~~x~~` are both struck through. With `subscript` on, a single tilde is claimed for subscripts: `~x~` is lowered, and only `~~x~~` strikes through. Turning the flag on therefore changes how existing `~x~` content renders.

### Admonitions

`MarkdownOptions(admonitions = true)` turns the five GitHub alert blockquotes into themed callouts:

```markdown
> [!WARNING]
> This action cannot be undone.
```

Without the option, `[!WARNING]` is just the first line of an ordinary quote. Style the result through the [`admonitions`](/android/api-reference/style-properties#admonitions) block.

### Highlight

`Md4cFlags(highlight = true)` renders `==text==` with a highlight band behind the glyphs. Exactly two equals signs form the marker, and it cannot open before a space or close after one, so `a == b` in prose stays literal.

Without the flag, `==text==` is ordinary text. Style the band through the [`highlight`](/android/api-reference/style-properties#highlight) block.

### Line break handling

Two options control how whitespace in the source survives into the output, and both matter most for **user-authored** text.

`MarkdownOptions(hardSoftBreaks = true)` makes every single newline a real line break. Markdown normally reflows lines within a paragraph, which surprises people writing chat messages or notes, where pressing Enter is expected to break the line.

`MarkdownOptions(preserveBlankLines = true)` keeps runs of blank lines instead of collapsing them, preserving deliberate vertical space.

### Permissive autolinks

`permissiveAutolinks` is the one extension that is **on** by default. It linkifies bare URLs (`https://swmansion.com`), `www.` addresses (`www.swmansion.com`), and email addresses (`hello@swmansion.com`) without their being wrapped in `<>`. Turn it off if you need a stricter parse in which only explicit `[text](url)` links and `<bracketed>` autolinks are live.

## Math is not an option

There is no `latexMath` option. `$...$` and `$$...$$` parse as math only where `LatexMathPlugin`, from the `math` artifact, is enabled - through a `LatexMathPlugin { }` scope or `plugins = listOf(LatexMathPlugin)` - so math is never parsed with nothing to draw it. Without the plugin the `$` stays literal text.

Setup, styling, error reporting, and what enabling math does to a dollar sign in prose are covered in [LaTeX math](/android/guides/latex-math).

## Spoilers

Spoilers have no option: `||text||` is **always** parsed and rendered hidden behind an overlay until the reader taps it. Pick the overlay with [`spoilerOverlay`](/android/api-reference/enriched-markdown-text#spoileroverlay) and color it with the [`spoiler`](/android/api-reference/style-properties#spoiler) block.

:::caution
Any two `||` in the same paragraph form a spoiler, with no rules about spaces around them, so `a || b` written twice in user-authored prose hides the text between them. Put such text in a code span, or escape a pipe (`\|`), where you control the source.
:::

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

Always on, with no option: tables, strikethrough, task lists, spoilers. On with `LatexMathPlugin`: LaTeX math. Never on: raw HTML.
