---
sidebar_label: Code highlighting
sidebar_position: 4
---

# Code highlighting

Code coloring ships as a **separate artifact**, `code-highlight`, so an app that never shows code does not carry a parser it will not use. It compiles [tree-sitter](https://tree-sitter.github.io/) and 14 grammars into one native library - about 8 MB per ABI as installed, about 1.1 MB per ABI compressed - which is why it is opt-in rather than part of `compose`.

Highlighting is **foreground-only**: it recolors tokens and changes nothing else, so a highlighted block measures exactly like a plain one.

## Adding the artifact

Add it next to `compose`, at the same version:

```kotlin
dependencies {
  implementation("com.swmansion.enriched.markdown:compose:<version>")
  implementation("com.swmansion.enriched.markdown:code-highlight:<version>")
}
```

:::note
The artifact is not on Maven Central yet. It will be published with the next release.
:::

## Turning it on

A plugin on the classpath does nothing until it is enabled. Call it as a scope around the part of the tree that should highlight code:

```kotlin
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.codehighlight.CodeHighlightPlugin

CodeHighlightPlugin {
  EnrichedMarkdownText(markdown = content)
}
```

Every `EnrichedMarkdownText` inside the scope highlights code - wrap one screen, or the whole app. `CodeHighlightPlugin { ... }` is shorthand for `MarkdownPlugins(CodeHighlightPlugin) { ... }`; to enable it together with other plugins, list them in one scope: `MarkdownPlugins(LatexMathPlugin, CodeHighlightPlugin) { ... }`. Plugin scopes nest independently of `MarkdownTheme`. To choose the plugins for a single instance, pass them as `EnrichedMarkdownText(plugins = listOf(CodeHighlightPlugin))`.

There is no parser flag. Without the plugin, fenced code renders exactly as before, in the [`codeBlock`](/android/api-reference/style-properties) color.

## What gets highlighted

The **language tag on the opening fence** picks the grammar:

````markdown
```python
def greet(name):
    return f"Hi, {name}"
```
````

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

Info strings match case-insensitively. A block with no tag, or a tag outside the table, renders plain. That includes Kotlin: there is no Kotlin grammar, so a `kotlin` block keeps the code block color.

Highlighting runs with the render, off the main thread. Tokens are cached per block, so a re-render - a style change, or a streamed message growing below its code - does not parse an unchanged block again. A block over 50 KB or 2,000 lines is left plain.

## Colors

Each of the 14 token types takes its color from the first of:

1. a color you set;
2. GitHub's palette - dark when the `codeBlock` `backgroundColor` is dark, light otherwise. The default code block is dark, so it gets the dark palette;
3. the `codeBlock` color. Operators, punctuation, variables, and embedded code have no palette color, so they land here unless you set one.

| Token | Dark palette | Light palette |
| --- | --- | --- |
| `keyword` | `#FF7B72` | `#CF222E` |
| `string` | `#A5D6FF` | `#0A3069` |
| `number`, `constant`, `property`, `attribute` | `#79C0FF` | `#0550AE` |
| `comment` | `#8B949E` | `#6E7781` |
| `function` | `#D2A8FF` | `#8250DF` |
| `type` | `#FFA657` | `#953800` |
| `tag` | `#7EE787` | `#116329` |
| `operator`, `punctuation`, `variable`, `embedded` | `codeBlock` color | `codeBlock` color |

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
