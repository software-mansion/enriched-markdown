---
sidebar_label: Code highlighting
sidebar_position: 0.75
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Code highlighting

Code coloring is built on [tree-sitter](https://tree-sitter.github.io/) and 14 bundled grammars. It ships as a **separate artifact**, `code-highlight`, rather than as part of `compose`, so an app that never shows code does not carry a parser it will not use.

Highlighting is **foreground-only**: it recolors tokens and changes nothing else, so a highlighted block measures exactly like a plain one. There is no parser flag to go with it - fenced code is always parsed with its language, so the plugin is the only switch.

## Installing the artifact {#installation}

Add `code-highlight` next to `compose`, using the same version for both (see [Installation](/android/basics/installation#artifacts) for the other artifacts):

<Tabs groupId="gradle-dsl">
  <TabItem value="kotlin" label="Kotlin DSL">

```kotlin
dependencies {
  implementation("com.swmansion.enriched.markdown:compose:0.3.0")
  implementation("com.swmansion.enriched.markdown:code-highlight:0.3.0")
}
```

  </TabItem>
  <TabItem value="groovy" label="Groovy">

```groovy
dependencies {
  implementation 'com.swmansion.enriched.markdown:compose:0.3.0'
  implementation 'com.swmansion.enriched.markdown:code-highlight:0.3.0'
}
```

  </TabItem>
</Tabs>

The artifact compiles tree-sitter and all 14 grammars into one native library, `libenriched_markdown_highlight.so`, built for `armeabi-v7a`, `arm64-v8a`, `x86`, and `x86_64` - every ABI the parser runs on. It costs about **8 MB per ABI** installed (an APK stores native libraries uncompressed by default) and about **1.1 MB per ABI** of download. Like the parser it ships `libc++_shared.so`, which the [`pickFirsts` rule](/android/basics/installation#native-libraries) already covers.

The artifact also ships its own consumer R8 rules - keeping the class its native library binds to by name, and stopping R8 from failing on a Compose runtime annotation in a View-only app - so minified builds need no configuration.

:::note
If the native library fails to load - an ABI split or `abiFilters` setting dropped it from the APK, say - nothing crashes. Logcat gets a single `CodeHighlighter` error and every code block renders in its plain `codeBlock` color.
:::

## Turning it on

A plugin on the classpath does nothing until it is enabled. Wrap the part of your UI that shows code in the plugin's scope:

```kotlin
import com.swmansion.enriched.markdown.codehighlight.CodeHighlightPlugin
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText

CodeHighlightPlugin {
  EnrichedMarkdownText(markdown = content)
}
```

Every `EnrichedMarkdownText` inside the scope highlights code, however deep, so you can wrap one screen or the whole app. `CodeHighlightPlugin { }` and the `CodeHighlightPlugin` object share one name and one import.

The scope is shorthand for the general [`MarkdownPlugins`](/android/api-reference/enriched-markdown-text#plugins). To enable it together with other plugins, list them in one scope:

```kotlin
import com.swmansion.enriched.markdown.codehighlight.CodeHighlightPlugin
import com.swmansion.enriched.markdown.compose.MarkdownPlugins
import com.swmansion.enriched.markdown.math.LatexMathPlugin

MarkdownPlugins(LatexMathPlugin, CodeHighlightPlugin) {
  HomeScreen()
}
```

To choose the plugins of a single instance instead, pass them directly. This **replaces** whatever the enclosing scopes enable:

```kotlin
import com.swmansion.enriched.markdown.codehighlight.CodeHighlightPlugin
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText

EnrichedMarkdownText(
  markdown = content,
  plugins = listOf(CodeHighlightPlugin),
)
```

### Without Compose {#without-compose}

Highlighting runs in the View-based renderer, so it works on an `EnrichedMarkdown` view directly. `code-highlight` depends on `ui` itself and needs `compose` only for the [style DSL](#styling) - a View-only app declares just `code-highlight`.

```kotlin
import android.content.Context
import com.swmansion.enriched.markdown.EnrichedMarkdown
import com.swmansion.enriched.markdown.codehighlight.CodeHighlightPlugin

fun codeView(context: Context, content: String): EnrichedMarkdown =
  EnrichedMarkdown(context).apply {
    setPlugins(listOf(CodeHighlightPlugin))
    setMarkdownContent(content)
  }
```

## What gets highlighted {#languages}

The **language tag on the opening fence** picks one of the bundled grammars:

| Language   | Info strings                 |
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
| TSX        | `tsx`                        |
| TypeScript | `typescript`, `ts`           |
| YAML       | `yaml`, `yml`                |

Info strings match case-insensitively. A block with no tag, or a tag outside the table, renders plain - and that includes **`kotlin`**, `swift`, `cpp`, `ruby`, `php`, and `csharp`, which have no grammar in this artifact.

Code blocks nested in a list item or a quote are highlighted like top-level ones.

### Limits and caching {#limits}

A block larger than **50 KB** of UTF-8 or longer than **2,000 lines** is not parsed and renders plain, so a pasted log cannot stall a render.

Tokens are cached in memory, keyed by the language and the code, in one process-wide cache of about 4 MB shared by every view. Scrolling a lazy list item back into view, a configuration change, or a theme change re-renders every block but does not parse an unchanged one again. A block that is still streaming in has new code on each update, so each update parses it once.

## Colors {#styling}

Each of the 14 token types takes its color from the first of:

1. a color you set;
2. GitHub's dark palette, made for the default dark code block (`#1F2937`);
3. the `codeBlock` color. Operators, punctuation, variables, and embedded code have no palette color, so they land here unless you set one.

| Token                                             | Default           |
| ------------------------------------------------- | ----------------- |
| `keyword`                                         | `#FF7B72`         |
| `string`                                          | `#A5D6FF`         |
| `number`, `constant`, `property`, `attribute`     | `#79C0FF`         |
| `comment`                                         | `#8B949E`         |
| `function`                                        | `#D2A8FF`         |
| `type`                                            | `#FFA657`         |
| `tag`                                             | `#7EE787`         |
| `operator`, `punctuation`, `variable`, `embedded` | `codeBlock` color |

:::caution
The palette does not follow the code block's background or the system theme. It suits the default dark code block in both light and dark mode, but if you give `codeBlock` a light `backgroundColor` - for instance from `MaterialTheme.colorScheme.surfaceVariant` in a light theme - set the token colors too, or comments and strings will be hard to read.
:::

Set colors with the `codeHighlight` block of the [`markdownStyle`](/android/api-reference/markdown-theme) builder. It is an extension function shipped by the artifact, so it needs its own import:

```kotlin
import androidx.compose.ui.graphics.Color
import com.swmansion.enriched.markdown.codehighlight.compose.codeHighlight
import com.swmansion.enriched.markdown.compose.markdownStyle

val oneDarkStyle = markdownStyle {
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

The properties are `keyword`, `operator`, `punctuation`, `string`, `number`, `constant`, `comment`, `function`, `type`, `variable`, `property`, `tag`, `attribute`, and `embedded`, each a `Color?`. A token you leave unset keeps its palette color. To pick the token at runtime, index the scope with a `SyntaxTokenType` (from `com.swmansion.enriched.markdown.codehighlight`): `this[SyntaxTokenType.KEYWORD] = color`.

Repeating the block merges into the earlier one, exactly like the built-in blocks, so `MarkdownStyle.merge { codeHighlight { … } }` layers over a base style and changes only what it names.

### Styling without Compose

On a View, the plugin reads its colors from the `StyleConfig` you pass to `setMarkdownStyle`, under `CodeHighlightStyleKey`. Colors there are ARGB ints, and the ones you leave `null` take the palette's:

```kotlin
import android.content.Context
import android.graphics.Color
import com.swmansion.enriched.markdown.EnrichedMarkdown
import com.swmansion.enriched.markdown.codehighlight.CodeHighlightStyle
import com.swmansion.enriched.markdown.codehighlight.CodeHighlightStyleKey
import com.swmansion.enriched.markdown.styles.StyleConfig

fun EnrichedMarkdown.applyCodeColors(context: Context) {
  setMarkdownStyle(
    StyleConfig.default(context).withExtension(
      CodeHighlightStyleKey,
      CodeHighlightStyle(
        keyword = Color.parseColor("#C678DD"),
        comment = Color.parseColor("#7F848E"),
      ),
    ),
  )
}
```

## Copying and accessibility {#copying}

Highlighting adds color and nothing else, so it changes nothing a reader copies or hears. **Copy** puts the code's plain text on the clipboard and its HTML in the `codeBlock` colors, without token colors; **Copy as Markdown** wraps the code in a plain ` ``` ` fence - the language tag is not carried over. TalkBack reads a highlighted block exactly as it reads a plain one.

## Licenses

tree-sitter and every bundled grammar are MIT-licensed. Their notices ship inside the artifact, under `META-INF/enriched-markdown-code-highlight/`, as `LICENSE-tree-sitter` and `LICENSE-grammars` - include them with your app's open-source notices.

## See also

- [Code-block highlighting](/rich-text-formatting/code-highlighting) - the feature at large.
- [Style properties](/android/api-reference/style-properties#codeblock) - the `codeBlock` style the highlighting sits on.
- [`EnrichedMarkdownText`](/android/api-reference/enriched-markdown-text#plugins) - the `plugins` parameter and plugin scopes.
