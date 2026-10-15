---
sidebar_label: Code highlighting
sidebar_position: 4
---

# Code highlighting

Code coloring is built on [tree-sitter](https://tree-sitter.github.io/) and 14 bundled grammars. It ships as a **separate artifact**, `code-highlight`, rather than as part of `compose`, so an app that never shows code does not carry a parser it will not use.

Highlighting is **foreground-only**: it recolors tokens and changes nothing else, so a highlighted block measures exactly like a plain one.

## Adding the artifact

Add it next to `compose`, at the same version:

```kotlin
dependencies {
  implementation("com.swmansion.enriched.markdown:compose:<version>")
  implementation("com.swmansion.enriched.markdown:code-highlight:<version>")
}
```

## Turning it on

A plugin on the classpath does nothing until it is enabled. Call it as a scope around the part of the tree that should highlight code:

```kotlin
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.codehighlight.CodeHighlightPlugin

CodeHighlightPlugin {
  EnrichedMarkdownText(markdown = content)
}
```

Every `EnrichedMarkdownText` inside the scope highlights code, so you can wrap one screen or the whole app.

`CodeHighlightPlugin { ... }` is shorthand for `MarkdownPlugins(CodeHighlightPlugin) { ... }`. To enable it together with other plugins, list them in one scope:

```kotlin
MarkdownPlugins(LatexMathPlugin, CodeHighlightPlugin) {
  EnrichedMarkdownText(markdown = content)
}
```

To choose the plugins for a single instance, pass them in the `plugins` parameter:

```kotlin
EnrichedMarkdownText(
  markdown = content,
  plugins = listOf(CodeHighlightPlugin),
)
```

## What gets highlighted

The **language tag on the opening fence** picks one of the bundled grammars:

| Language | Info strings |
| --- | --- |
| Bash | `bash`, `sh`, `shell`, `zsh` |
| C | `c` |
| CSS | `css` |
| Go | `go`, `golang` |
| HTML | `html` |
| Java | `java` |
| JavaScript | `javascript`, `js`, `jsx` |
| JSON | `json` |
| Markdown | `markdown`, `md` |
| Python | `python`, `py` |
| Rust | `rust`, `rs` |
| TSX | `tsx` |
| TypeScript | `typescript`, `ts` |
| YAML | `yaml`, `yml` |

Info strings match case-insensitively. A block with no tag, or a tag outside the table, renders plain.

## Colors

Each of the 14 token types takes its color from the first of:

1. a color you set;
2. GitHub's dark palette, made for the default dark code block;
3. the `codeBlock` color. Operators, punctuation, variables, and embedded code have no palette color, so they land here unless you set one.

| Token | Default |
| --- | --- |
| `keyword` | `#FF7B72` |
| `string` | `#A5D6FF` |
| `number`, `constant`, `property`, `attribute` | `#79C0FF` |
| `comment` | `#8B949E` |
| `function` | `#D2A8FF` |
| `type` | `#FFA657` |
| `tag` | `#7EE787` |
| `operator`, `punctuation`, `variable`, `embedded` | `codeBlock` color |

The palette does not change with the code block's background. If you give `codeBlock` a light `backgroundColor`, set the token colors too.

Set colors with the `codeHighlight` block. It is an extension function shipped by the artifact, so it needs an import:

```kotlin
import com.swmansion.enriched.markdown.codehighlight.compose.codeHighlight

markdownStyle {
  codeBlock {
    color = Color(0xFFABB2BF)
    backgroundColor = Color(0xFF282C34)
  }
  codeHighlight {
    keyword = Color(0xFFC678DD)
    string = Color(0xFF98C379)
    comment = Color(0xFF7F848E)
  }
}
```

The properties are `keyword`, `operator`, `punctuation`, `string`, `number`, `constant`, `comment`, `function`, `type`, `variable`, `property`, `tag`, `attribute`, and `embedded`. Repeating the block merges into the earlier one, so `MarkdownStyle.merge { codeHighlight { ... } }` layers over a base style like any built-in block.

## Licenses

tree-sitter and every bundled grammar are MIT-licensed. Their notices ship inside the artifact, under `META-INF/enriched-markdown-code-highlight/`, as `LICENSE-tree-sitter` and `LICENSE-grammars` - include them with your app's open-source notices.

## See also

- [Code-block highlighting](/rich-text-formatting/code-highlighting) - the feature across platforms.
- [Style properties](/android/api-reference/style-properties) - the `codeBlock` style the highlighting sits on.
