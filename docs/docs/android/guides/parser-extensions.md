---
sidebar_label: Parser extensions
sidebar_position: 0
---

# Parser extensions

Markdown is not one language. Beyond the [CommonMark](https://spec.commonmark.org/) core that every renderer agrees on, each flavor adds its own syntax, and this library lets you pick which of those additions are in play - per component, through the [`flags`](/android/api-reference/enriched-markdown-text#flags) parameter.

This guide is about what those flags do and when to reach for them. For the bare list with types and defaults, see the [`EnrichedMarkdownText` reference](/android/api-reference/enriched-markdown-text#flags).

## There is no flavor switch

There is no single setting that flips the parser between [CommonMark](https://spec.commonmark.org/) and [GitHub Flavored Markdown](https://github.github.com/gfm/). Instead:

- The **GitHub table, strikethrough, and task list** extensions are always on. There is nothing to enable and no way to turn them off - `~~struck~~` and `- [ ]` always mean what you expect.
- **Everything else** is an individual flag you opt into.

So the question is never "which flavor am I in", only "is this particular piece of syntax enabled".

## The parsing model

Parsing happens in C++, in [md4c](https://github.com/mity/md4c), reached through JNI. The flags you pass are translated into md4c's own feature flags before the document is parsed, which has two consequences worth internalizing:

**Flags change parsing, not painting.** With a flag off, its syntax is never recognized as syntax - the characters stay ordinary text. `^2^` with `superscript` off is a literal caret, two, caret. Nothing is hidden or stripped; it simply was never markup.

**Flags are per component and change the parse.** Passing a new `Md4cFlags` re-parses the document, so treat the value as part of your content rather than as a setting to toggle at speed:

```kotlin
EnrichedMarkdownText(
  markdown = content,
  flags = Md4cFlags(underline = true, admonitions = true),
)
```

Raw HTML is never parsed as HTML. `<b>bold</b>` in your source renders as literal text, on every flag combination.

## The extensions

### Underline

`Md4cFlags(underline = true)` **repurposes** the underscore markers: `_text_` and `__text__` render underlined instead of italic and bold.

This is a trade, not an addition. With the flag on you can still write italic and bold - as `*text*` and `**text**` - but the underscore spellings stop meaning what they do everywhere else. Turn it on for content you control; be careful with user-authored Markdown, where people write `_italic_` and expect italics.

### Superscript and subscript

`Md4cFlags(superscript = true)` renders `^text^` raised; `Md4cFlags(subscript = true)` renders `~text~` lowered. They're independent flags, and worth enabling together for anything with formulas or footnote markers - `E = mc^2^`, `H~2~O`.

One interaction to know: `subscript` claims a single tilde, while strikethrough uses two. `~x~` is a subscript and `~~x~~` is struck through, so the two coexist, but a lone tilde in prose stops being literal.

### Admonitions

`Md4cFlags(admonitions = true)` turns the five GitHub alert blockquotes into themed callouts:

```markdown
> [!WARNING]
> This action cannot be undone.
```

Without the flag, `[!WARNING]` is just the first line of an ordinary quote. Style the result through the [`admonitions`](/android/api-reference/style-properties#admonitions) block.

### Line break handling

Two flags control how whitespace in the source survives into the output, and both matter most for **user-authored** text.

`Md4cFlags(hardSoftBreaks = true)` makes every single newline a real line break. Markdown normally reflows lines within a paragraph, which surprises people writing chat messages or notes, where pressing Enter is expected to break the line.

`Md4cFlags(preserveBlankLines = true)` keeps runs of blank lines instead of collapsing them, preserving deliberate vertical space.

### Permissive autolinks

`permissiveAutolinks` is the one extension that is **on** by default. It linkifies bare URLs, so `https://swmansion.com` becomes a link without being wrapped in `<>`. Turn it off if you need a stricter parse in which only explicit `[text](url)` links and `<bracketed>` autolinks are live.

## Two flags to leave off

`highlight` and `latexMath` parse, but the Android renderer has no drawing code for the nodes they produce.

:::danger
Enabling either **removes content from the page**. An unrendered node's text is dropped rather than shown unstyled, so `==important==` and `$E = mc^2$` render as nothing at all, with a `No renderer for: …` warning in Logcat. Leave both off: the `==` and `$` then stay literal text, and your reader still sees the words.
:::

The same is true of two constructs that have no flag at all: **tables** and **spoilers** parse - tables always, spoilers unconditionally - but are skipped at render time. Renderers for all four are in progress; see the [roadmap](/misc/roadmap#android-renderer).

## Reference

| Flag | Default | Enables |
| --- | --- | --- |
| `permissiveAutolinks` | `true` | Bare URLs become links |
| `underline` | `false` | `_text_` / `__text__` render underlined |
| `superscript` | `false` | `^text^` renders raised |
| `subscript` | `false` | `~text~` renders lowered |
| `admonitions` | `false` | `> [!NOTE]` renders as a callout |
| `hardSoftBreaks` | `false` | A single newline is a line break |
| `preserveBlankLines` | `false` | Consecutive blank lines are kept |
| `highlight` | `false` | Parses `==text==` - **no renderer, drops the text** |
| `latexMath` | `false` | Parses `$math$` - **no renderer, drops the text** |

Always on, with no flag: tables, strikethrough, task lists. Never on: raw HTML.
