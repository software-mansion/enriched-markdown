---
sidebar_label: Syntax highlighting
sidebar_position: 2.5
---

# Syntax highlighting

Code-block coloring ships as a **separate product**, `EnrichedMarkdownSyntaxHighlighting`, because it compiles the tree-sitter parsing library and a fixed set of language grammars into your app - about 8 MB of app size. An app that never shows code should not pay for that, so the base package draws every code block in a single color.

The consequence to know up front: linking the product colors nothing on its own. Highlighting is switched on per view, by a modifier, and only for code blocks whose fence names a language the product has a grammar for. Everything else renders as plain code - never mangled, never missing.

## Turning it on

Add the `EnrichedMarkdownSyntaxHighlighting` product alongside `EnrichedMarkdown` (see [The products](/ios/basics/installation#products)), then enable it per view:

```swift
import EnrichedMarkdown
import EnrichedMarkdownSyntaxHighlighting
import SwiftUI

struct SnippetView: View {
  let content: String

  var body: some View {
    EnrichedMarkdownText(content)
      .markdownSyntaxHighlighting()
  }
}
```

### `.markdownSyntaxHighlighting(_:)` {#markdownsyntaxhighlighting}

Colors fenced code blocks by the language their fence names. Like every other modifier it reads from the environment, so applying it to a container enables highlighting for every `EnrichedMarkdownText` beneath it, and `.markdownSyntaxHighlighting(false)` turns it back off for a subtree.

<PropInfo type="Bool" default="true" />

```swift
VStack {
  EnrichedMarkdownText(article)
  EnrichedMarkdownText(rawLog)
    .markdownSyntaxHighlighting(false)
}
.markdownSyntaxHighlighting()
```

It combines freely with [`.markdownLaTeX()`](/ios/guides/latex-math) and [`.markdownCodeBlockLayout(_:)`](/ios/api-reference/enriched-markdown-text#markdowncodeblocklayout).

## Which grammar a block gets {#languages}

The grammar comes from the fence's **info string** - its first word, matched case-insensitively. Anything after the first word is ignored: a fence opened with `py title="setup.py"` selects Python. These are the bundled grammars and the names that select them:

| Grammar    | Info strings                 |
| ---------- | ---------------------------- |
| Bash       | `bash`, `sh`, `shell`, `zsh` |
| C          | `c`                          |
| CSS        | `css`                        |
| Go         | `go`, `golang`               |
| HTML       | `html`                       |
| Java       | `java`                       |
| JavaScript | `javascript`, `js`, `jsx`    |
| JSON       | `json`                       |
| Markdown   | `markdown`, `md`             |
| Python     | `python`, `py`               |
| Rust       | `rust`, `rs`                 |
| TypeScript | `typescript`, `ts`           |
| TSX        | `tsx`                        |
| YAML       | `yaml`, `yml`                |

````markdown
```python
def area(r):
    return 3.14159 * r ** 2
```
````

A block renders as **plain code**, in the [`CodeBlock()`](/ios/api-reference/style-properties#codeblock) color, when:

- the fence names no language;
- the language has no grammar in the list above. That includes languages a `.scrollable` panel still names in its header, such as `swift`, `cpp`, `ruby`, `php`, `csharp`, `sql`, and `kotlin` - **Swift code is not highlighted**;
- the block is larger than 50 KB or longer than 2,000 lines, which keeps a pathological block from stalling a render.

## What highlighting changes

Highlighting is **foreground-only**: it recolors runs of code and nothing else. Font, background, padding, border, corner radius, margins, and line height all still come from [`CodeBlock()`](/ios/api-reference/style-properties#codeblock), and text selection, copying, and VoiceOver behave exactly as they do for an uncolored block. The copied text is the plain code.

Each run is classified as one of the `SyntaxTokenType` cases:

```swift
public enum SyntaxTokenType: UInt8, CaseIterable, Sendable {
  case keyword, `operator`, punctuation, string, number, constant, comment
  case function, type, variable, property, tag, attribute, embedded
}
```

A run whose type has no color in the theme keeps the `CodeBlock()` foreground color. The same applies to any text the grammar does not classify at all.

## Theming the colors {#theming}

Token colors are theme elements: [`SyntaxToken(_:)`](/ios/api-reference/style-properties#syntaxtoken) takes a `SyntaxTokenType` and one modifier, `.foregroundStyle(_:)`, accepting a `Color` or a semantic color (`.primary`, `.secondary`, `.tertiary`, `.quaternary`, `.tint`).

```swift
import EnrichedMarkdown
import EnrichedMarkdownSyntaxHighlighting
import SwiftUI

let codeTheme = MarkdownTheme {
  SyntaxToken(.keyword).foregroundStyle(Color(.systemPink))
  SyntaxToken(.comment).foregroundStyle(.secondary)
  SyntaxToken(.operator).foregroundStyle(.tint)
}

struct SnippetView: View {
  let content: String

  var body: some View {
    EnrichedMarkdownText(content)
      .markdownSyntaxHighlighting()
      .markdownTheme(codeTheme)
  }
}
```

Each `SyntaxToken` sets one type and leaves the others alone, so a theme only needs the types it changes. A fixed `Color(red:green:blue:)` stays the same in light and dark mode; a dynamic system color such as `Color(.systemPink)` adapts - see [Dark mode and Dynamic Type](/ios/api-reference/style-properties#adaptive-values).

### The default palette {#default-palette}

`.markdownSyntaxHighlighting()` inserts `MarkdownTheme.syntaxHighlightingDefault` directly **above** `MarkdownTheme.default` and **below** every theme you apply, so your `SyntaxToken` overrides win wherever you applied them. The default is GitHub's palette, switching with the color scheme:

| Token type   | Light     | Dark      |
| ------------ | --------- | --------- |
| `.keyword`   | `#CF222E` | `#FF7B72` |
| `.string`    | `#0A3069` | `#A5D6FF` |
| `.number`    | `#0550AE` | `#79C0FF` |
| `.constant`  | `#0550AE` | `#79C0FF` |
| `.comment`   | `#6E7781` | `#8B949E` |
| `.function`  | `#8250DF` | `#D2A8FF` |
| `.type`      | `#953800` | `#FFA657` |
| `.property`  | `#0550AE` | `#79C0FF` |
| `.tag`       | `#116329` | `#7EE787` |
| `.attribute` | `#0550AE` | `#79C0FF` |

`.operator`, `.punctuation`, `.variable`, and `.embedded` have no default color and render in the `CodeBlock()` foreground color until you give them one.

## Header and copy button {#code-block-panel}

The language header and the copy button do **not** come from this product. They are part of the base package's [`.markdownCodeBlockLayout(.scrollable)`](/ios/api-reference/enriched-markdown-text#markdowncodeblocklayout), which works with or without highlighting, and [`.onCodeBlockCopy`](/ios/api-reference/enriched-markdown-text#oncodeblockcopy) reports copies in either case. Together they make the usual code-viewer setup:

```swift
import EnrichedMarkdown
import EnrichedMarkdownSyntaxHighlighting
import SwiftUI

struct SnippetView: View {
  let content: String
  @State private var lastCopiedLanguage: String?

  var body: some View {
    EnrichedMarkdownText(content)
      .markdownSyntaxHighlighting()
      .markdownCodeBlockLayout(.scrollable)
      .onCodeBlockCopy { copy in
        lastCopiedLanguage = copy.language
      }
  }
}
```

Highlighting applies to both layouts: a `.wrapping` block is colored the same way, it just has no header or copy button.

## Cost and caching {#caching}

Highlighting a block means parsing it with its grammar, which happens as part of rendering the document. The resulting token ranges are cached in memory, keyed by a hash of the language and the code, for up to 128 blocks or 4 MB. A re-render that leaves a block's code unchanged - a theme or appearance change, a Dynamic Type switch, a streamed token appended to a later paragraph - reuses its tokens instead of parsing again, and a palette change only re-applies colors. Each grammar's highlight query is compiled once per process and reused.

The cache is process-wide, shared by every view, and has no public API to clear or resize.

## Rendering without a view {#rendering-without-a-view}

`MarkdownRenderer.renderSyntaxHighlighted` is [`MarkdownRenderer.render`](/ios/api-reference/markdown-theme#markdownrenderer) with highlighting installed. It takes the same parameters, including `codeBlockLayout:`:

````swift
import EnrichedMarkdown
import EnrichedMarkdownSyntaxHighlighting
import UIKit

let myTheme = MarkdownTheme {
  SyntaxToken(.comment).foregroundStyle(.secondary)
}

let content = """
```python
answer = 42  # computed elsewhere
```
"""

let config = MarkdownStyleConfiguration.resolve(
  layers: [.default, .syntaxHighlightingDefault, myTheme],
  traitCollection: .current
)

let text = MarkdownRenderer.renderSyntaxHighlighted(content, config: config)
````

:::caution
Resolving the config yourself means **you** place the `.syntaxHighlightingDefault` layer. `MarkdownStyleConfiguration.baseline()` is `.default` alone, and a config with no token colors at all leaves every block **uncolored** - the grammar runs, nothing changes. Include `.syntaxHighlightingDefault` between `.default` and your own layers, exactly as `.markdownSyntaxHighlighting()` does, or set every `SyntaxToken` you want colored in your own theme.
:::

`renderSyntaxHighlighted` installs highlighting only, and [`renderLaTeX`](/ios/guides/latex-math#rendering-without-a-view) installs math only: there is no public entry point that renders one string with both. A view takes both modifiers at once. The same caveat as `render` applies to the returned string: code block backgrounds and the other decorations `EnrichedMarkdownText` draws around the text are not in it - see [UIKit interop](/ios/guides/uikit-interop).

## See also

- [`CodeBlock()`](/ios/api-reference/style-properties#codeblock) - font, background, and spacing of code blocks.
- [Code blocks](/ios/api-reference/enriched-markdown-text#markdowncodeblocklayout) - the scrollable panel, its header, and copy reporting.
- [LaTeX math](/ios/guides/latex-math) - the other optional product, set up the same way.
