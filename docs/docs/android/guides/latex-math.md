---
sidebar_label: LaTeX math
sidebar_position: 0.5
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# LaTeX math

Math rendering ships as a **separate artifact**, `math`, so an app that never shows a formula does not carry a typesetting engine it will not use. The artifact brings in [RaTeX](#engine), a native LaTeX engine with the KaTeX fonts, which is why it is opt-in rather than part of `compose`.

Two switches have to be on before a formula is typeset, and they are independent:

- **The parser flag**, `Md4cFlags(latexMath = true)`, makes `$…$` and `$$…$$` math syntax at all. With it off, a dollar sign is ordinary text, plugin or not.
- **The plugin**, `LatexMathPlugin`, draws what the parser found. With the flag on and no plugin, every formula renders as its **raw source**, delimiters included - nothing is lost, and Logcat carries a single `EnrichedMarkdown` warning naming the missing artifact.

## Installing the artifact {#installation}

Add `math` next to `compose`, using the same version for both (see [Installation](/android/basics/installation#artifacts) for the other artifacts):

<Tabs groupId="gradle-dsl">
  <TabItem value="kotlin" label="Kotlin DSL">

```kotlin
dependencies {
  implementation("com.swmansion.enriched.markdown:compose:0.3.0")
  implementation("com.swmansion.enriched.markdown:math:0.3.0")
}
```

  </TabItem>
  <TabItem value="groovy" label="Groovy">

```groovy
dependencies {
  implementation 'com.swmansion.enriched.markdown:compose:0.3.0'
  implementation 'com.swmansion.enriched.markdown:math:0.3.0'
}
```

  </TabItem>
</Tabs>

The RaTeX engine comes in transitively from Maven Central, so there is nothing else to declare. The artifact also ships its own consumer R8 rules, so minified builds need no configuration.

:::caution
RaTeX's native library ships for `arm64-v8a`, `armeabi-v7a` and `x86_64` only - **there is no 32-bit `x86` build**. On such a device, most often an old x86 emulator image, math does not crash the app: every formula renders as its source, Logcat gets one `RaTeX` warning per process, and each formula reports a [`LatexError`](#errors). Test math on an `x86_64` or ARM image.
:::

## Turning it on

Wrap the part of your UI that shows math in the plugin's scope, and enable the flag on each `EnrichedMarkdownText`:

```kotlin
import androidx.compose.runtime.Composable
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.compose.Md4cFlags
import com.swmansion.enriched.markdown.math.LatexMathPlugin

@Composable
fun FormulaScreen(content: String) {
  LatexMathPlugin {
    EnrichedMarkdownText(
      markdown = content,
      flags = Md4cFlags(latexMath = true),
    )
  }
}
```

The scope enables the plugin for every `EnrichedMarkdownText` beneath it, however deep, so wrapping your app's root once is enough. `LatexMathPlugin { }` and the `LatexMathPlugin` object share one name and one import.

The scope is shorthand for the general [`MarkdownPlugins`](/android/api-reference/enriched-markdown-text#plugins), which takes any number of plugins. Scopes nest: an inner scope adds its plugins to the ones enabled outside it, and re-enabling a plugin that is already on replaces it rather than adding a second copy.

```kotlin
import com.swmansion.enriched.markdown.compose.MarkdownPlugins
import com.swmansion.enriched.markdown.math.LatexMathPlugin

MarkdownPlugins(LatexMathPlugin) {
  HomeScreen()
}
```

To choose the plugins of a single instance instead, pass them directly. This **replaces** whatever the enclosing scopes enable:

```kotlin
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.compose.Md4cFlags
import com.swmansion.enriched.markdown.math.LatexMathPlugin

EnrichedMarkdownText(
  markdown = content,
  flags = Md4cFlags(latexMath = true),
  plugins = listOf(LatexMathPlugin),
)
```

### Without Compose {#without-compose}

The plugin renders through the View-based renderer, so it works on an `EnrichedMarkdown` view directly. `math` depends on `ui` itself, and needs `compose` only for the [style DSL](#styling) - a View-only app declares just `math`.

```kotlin
import android.content.Context
import com.swmansion.enriched.markdown.EnrichedMarkdown
import com.swmansion.enriched.markdown.math.LatexMathPlugin
import com.swmansion.enriched.markdown.parser.Md4cFlags

fun formulaView(context: Context, content: String): EnrichedMarkdown =
  EnrichedMarkdown(context).apply {
    setMd4cFlags(Md4cFlags(latexMath = true))
    setPlugins(listOf(LatexMathPlugin))
    setMarkdownContent(content)
  }
```

`setPlugins` compares lists by value, so passing an equal list again does nothing.

## What renders

- **`$…$`** typesets inline, at the font size of the text around it - a formula in a heading is heading-sized.
- **`$$…$$`** in a top-level paragraph that starts or ends a line becomes a **block** of its own: a full-width panel, centered by default. A formula wider than the view **scrolls horizontally** inside the panel.

```markdown
The area is $\pi r^2$, and the general form is:

$$
\int_{0}^{1} x^2 \,dx = \frac{1}{3}
$$
```

Display math does not always become a block. `$$…$$` with text on **both** sides on the same line (`a $$x$$ b`), or inside a list item, quote, or table cell, stays in the line and is typeset like inline math, at the size of the surrounding text.

A block has no text selection. Long-pressing it opens a menu with **Copy**, which copies the bare LaTeX, and **Copy as Markdown**, which copies it wrapped in `$$` lines. Inline formulas take part in ordinary text selection: a plain copy puts the bare LaTeX on the clipboard, and a Markdown copy keeps the `$` delimiters.

### What `$` costs in prose {#dollar-signs}

With the flag on, a `$` at the start of a word can open math, and the next `$` with the same count that ends a word - followed by a space, punctuation, or the end of the line - closes it. Everything between becomes a formula. Most prices survive, because `$5 and $10` has no closing `$`, but a document that also puts a dollar sign at the end of a word can lose a sentence to an accidental formula.

Turn the flag on for content that is meant to contain math, and escape a literal dollar sign as `\$` where you control the source. Code spans are never parsed as math, so `` `echo $HOME` `` is safe either way.

## Styling {#styling}

The artifact adds two blocks to the [`markdownStyle`](/android/api-reference/markdown-theme) builder. They are extension functions, so each needs its own import before it resolves:

```kotlin
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.compose.MarkdownTheme
import com.swmansion.enriched.markdown.compose.Md4cFlags
import com.swmansion.enriched.markdown.math.compose.inlineMath
import com.swmansion.enriched.markdown.math.compose.math

@Composable
fun StyledFormula(content: String) {
  EnrichedMarkdownText(
    markdown = content,
    flags = Md4cFlags(latexMath = true),
    style = MarkdownTheme.style.merge {
      math {
        fontSize = 22.sp
        backgroundColor = Color(0xFFEEF2FF)
        padding = 16.dp
        marginBottom = 24.dp
        alignment = Alignment.Start
      }
      inlineMath {
        color = Color(0xFF4F46E5)
      }
    },
  )
}
```

Properties you leave unset keep the plugin's defaults. Repeating a block merges into the earlier one, exactly like the built-in blocks, so a `merge { math { … } }` layer changes only what it names.

### `math` {#math}

Block math (`$$…$$` on its own line). The typeface is always the engine's KaTeX font; there is no `fontFamily`.

| Property          | Type                   | Default                        |
| ----------------- | ---------------------- | ------------------------------ |
| `fontSize`        | `TextUnit`             | `20.sp`                        |
| `color`           | `Color`                | `#1F2937`                      |
| `backgroundColor` | `Color`                | `#F3F4F6`                      |
| `padding`         | `Dp`                   | `12.dp`, on every side         |
| `marginTop`       | `Dp`                   | `0.dp`                         |
| `marginBottom`    | `Dp`                   | `16.dp`                        |
| `alignment`       | `Alignment.Horizontal` | `Alignment.CenterHorizontally` |

`alignment` places the equation inside its panel. `Alignment.Start`, `Alignment.CenterHorizontally` and `Alignment.End` follow the reading direction; `AbsoluteAlignment.Left` and `AbsoluteAlignment.Right` pin a side regardless of it.

### `inlineMath` {#inlinemath}

Inline math (`$…$`, and display math that stays in the line). Takes `color` only, defaulting to `#1F2937`; the size follows the surrounding text.

:::caution
Neither color follows the paragraph. Both defaults are fixed light-theme colors, so in a dark theme set `math { color; backgroundColor }` and `inlineMath { color }` yourself, alongside your paragraph color.
:::

### Styling without Compose

On a View, the plugin reads its style from the `StyleConfig` you pass to `setMarkdownStyle`, under `MathStyleKey` and `InlineMathStyleKey`. Values there are in the units `StyleConfig` stores everywhere - pixels and ARGB ints. Start from the resolved defaults and change what you need:

```kotlin
import android.content.Context
import android.graphics.Color
import com.swmansion.enriched.markdown.EnrichedMarkdown
import com.swmansion.enriched.markdown.math.InlineMathStyle
import com.swmansion.enriched.markdown.math.InlineMathStyleKey
import com.swmansion.enriched.markdown.math.MathStyleKey
import com.swmansion.enriched.markdown.math.mathStyle
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.TextAlignment

fun EnrichedMarkdown.applyMathStyle(context: Context) {
  val base = StyleConfig.default(context)
  setMarkdownStyle(
    base
      .withExtension(MathStyleKey, base.mathStyle(context).copy(textAlign = TextAlignment.START))
      .withExtension(InlineMathStyleKey, InlineMathStyle(color = Color.parseColor("#4F46E5"))),
  )
}
```

## Errors {#errors}

Source the engine cannot typeset falls back to its **delimited source** - `$\frac{1}{}$` renders as that literal string rather than vanishing - so a typo in one formula never blanks a paragraph. An inline formula falls back to text styled like its surroundings; a block keeps its panel and shows `$$…$$` inside it.

Each failure is also reported through [`onPluginEvent`](/android/api-reference/enriched-markdown-text#onpluginevent) as a `LatexError`:

```kotlin
import android.util.Log
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.compose.Md4cFlags
import com.swmansion.enriched.markdown.math.LatexError

EnrichedMarkdownText(
  markdown = content,
  flags = Md4cFlags(latexMath = true),
  onPluginEvent = { event ->
    if (event is LatexError) {
      Log.w("Math", "Could not render ${event.source}: ${event.message}")
    }
  },
)
```

```kotlin
data class LatexError(
  val source: String,       // the expression, without its $ / $$ delimiters
  val message: String?,     // the engine's error, when it gave one
  val displayMode: Boolean, // false for $…$, true for $$…$$
  override val pluginId: String = LatexMathPlugin.ID,
) : PluginEvent
```

Events arrive on the main thread, **once per distinct error** until the markdown is replaced. Appending to the markdown does not reset that, so streamed content that re-renders the same broken formula on every token reports it once. On a View, the same events go to `setOnPluginEventCallback`.

A half-arrived block - an opening `$$` whose formula is still empty - is not an error: it renders as text until the content arrives.

## Accessibility {#accessibility}

A math **block** is a single focusable element that TalkBack reads as `"Math: "` followed by the raw LaTeX source - `"Math: \frac{1}{3}"`, not a spoken rendering. The label is not configurable.

An **inline** formula has no spoken form of its own: it is drawn over a single placeholder character in the text, which TalkBack does not read out. If a formula carries meaning a reader would miss, say it in the surrounding prose too.

## The engine {#engine}

**LaTeX** is the markup you write between the dollar signs. **RaTeX** is the native engine that turns it into positioned glyphs, pulled in by the `math` artifact. **KaTeX** is the math project whose fonts RaTeX draws with; they ship inside the engine and load the first time a formula renders. They change nothing about the rest of your text, and they are why a formula keeps the familiar TeX look whatever font the surrounding Markdown uses.

## See also

- [Parser extensions](/android/guides/parser-extensions) - the other flags, and what each one changes about parsing.
- [LaTeX math](/rich-text-formatting/latex-math) - the feature at large, including which syntax is supported.
- [`EnrichedMarkdownText`](/android/api-reference/enriched-markdown-text#plugins) - the `plugins` and `onPluginEvent` parameters.
