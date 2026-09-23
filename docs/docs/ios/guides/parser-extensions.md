---
sidebar_label: Parser extensions
sidebar_position: 1
---

# Parser extensions

`MarkdownParsingOptions` decides **what the parser recognizes**, not how it looks. An option that is off does not hide an element - it means the syntax was never an element in the first place, and the markers stay in the text as you typed them. Getting one wrong therefore shows up as literal `==` or `^` in your output, not as an unstyled span.

```swift
EnrichedMarkdownText(content, options: MarkdownParsingOptions(underline: true, admonitions: true))
```

Options are per view, and the default `.commonMark` turns **everything off except `permissiveAutolinks`**. This page walks through what each one changes and what it costs.

## What is always on

Four things need no option and cannot be turned off:

- **Tables**, **task lists**, and **strikethrough** - the GFM set.
- **Spoilers** (`||text||`).

If a document uses `~~` or `|` for something else, that is the one thing to know before rendering it.

## Extensions that change an existing meaning

These two reassign characters Markdown already uses. They are the options worth being deliberate about.

### `underline`

Makes `_text_` and `__text__` underlined instead of italic and bold.

```swift
MarkdownParsingOptions(underline: true)
```

The asterisk forms are untouched, so `*italic*` and `**bold**` keep working. But a document written by someone who used underscores for emphasis will come out **underlined** everywhere. Enable it for content you control - your own release notes, say - and leave it off for arbitrary Markdown from the internet.

Style it with the [`Underline()`](/ios/api-reference/style-properties#underline) element.

### `subscript`

Makes `~text~` lowered text.

```swift
MarkdownParsingOptions(subscript: true)
```

Strikethrough is always on and uses the doubled form, so `~~struck~~` still works alongside it. The collision is with **single** tildes used as decoration or as a literal character: `~5 minutes` becomes a subscripted run rather than "about 5 minutes".

## Extensions that add new syntax

These four only add meaning to characters Markdown ignores today, so they are safe to enable on content you did not write.

### `superscript`

`^text^` renders raised. Sizing is a fraction of the surrounding text - see [`Superscript()`](/ios/api-reference/style-properties#superscript--subscript).

### `highlight`

`==text==` renders with a background.

:::caution
The default highlight background is a fixed light yellow, and it does not adapt to dark mode. If you enable this option, set both a background **and** a foreground on [`Highlight()`](/ios/api-reference/style-properties#highlight) for every appearance you support, or a highlighted run will be unreadable in dark mode.
:::

### `admonitions` {#admonitions}

A blockquote whose first line is `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, or `> [!CAUTION]` renders as a callout with a tinted bar, an icon, and a title.

```markdown
> [!TIP]
> Long-press a table to copy it as Markdown.
```

Without it the marker is literal text on the first line of an ordinary quote - which is exactly what GitHub-flavored source will look like if you forget it. Colors come from [`Admonition()`](/ios/api-reference/style-properties#admonition).

### `preserveBlankLines`

Keeps consecutive blank lines instead of collapsing them into a single paragraph break, so deliberate vertical whitespace in the source survives.

## Extensions that change layout

### `hardSoftBreaks`

Treats every single newline as a real line break instead of reflowing the paragraph.

```swift
MarkdownParsingOptions(hardSoftBreaks: true)
```

Reach for this whenever you render **text a person typed** - chat messages, notes, comments - where pressing Return is expected to produce a line break. Leave it off for authored documents, where reflowing is the point.

### `permissiveAutolinks`

The one option that is **on** by default. It links bare URLs, `www.` hosts, and email addresses:

```markdown
Read more at https://swmansion.com or write to hello@example.com.
```

With it off, only the angle-bracket form (`<https://swmansion.com>`) autolinks; a bare URL stays inert text. `[text](url)` is an ordinary inline link and works either way.

Turn it off when a document contains URL-shaped text that must not become tappable - a log excerpt, say, or user input you have not vetted.

```swift
EnrichedMarkdownText(userInput, options: MarkdownParsingOptions(permissiveAutolinks: false))
```

## Math is not an option

`$…$` and `$$…$$` do **not** have a `MarkdownParsingOptions` entry. Math parsing is switched on by the `EnrichedMarkdownLaTeX` product's [`.markdownLaTeX()`](/ios/guides/latex-math) modifier, which enables it and installs the renderer in one step - so it is impossible to parse math the base package cannot draw. Without the product, `$x^2$` stays plain text.

## Options travel with the copy

A document remembers the options it was rendered with, and **Copy as Markdown** re-parses the selection with those same options. So a partial selection out of an underline-enabled document comes back with underline markers intact, rather than reconstructed as bold. Nothing to configure - it is worth knowing only if you see copied output that does not match a default-options parse.

## See also

- [`options`](/ios/api-reference/enriched-markdown-text#options) - the reference entry for every field.
- [Element structure](/ios/api-reference/element-structure) - what each construct renders as once its option is on.
- [Markdown flavors](/introduction/core-concepts#markdown-flavors) - where these extensions come from.
