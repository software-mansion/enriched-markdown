---
sidebar_label: MarkdownTheme
sidebar_position: 2
---

# MarkdownTheme

This page covers the composables that **provide and build** styles. For the styleable elements and their properties, see [Style properties](/android/api-reference/style-properties).

A style reaches a component one of two ways: from the nearest enclosing `MarkdownTheme`, or from the component's own `style` parameter, which wins. Provide a theme once near the top of your UI and override per instance only where something has to differ.

## `MarkdownTheme`

```kotlin
@Composable
fun MarkdownTheme(
  style: MarkdownStyle,
  content: @Composable () -> Unit,
)
```

Provides `style` as the default for everything inside `content`. Themes nest, and the innermost one wins:

```kotlin
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.compose.MarkdownTheme

MarkdownTheme(style = appStyle) {
  HomeScreen()

  MarkdownTheme(style = compactStyle) {
    ChatBubble(markdown = message) // uses compactStyle
  }
}
```

#### `style` {#markdowntheme-style-param}

The style every `EnrichedMarkdownText` inside `content` uses unless it passes its own. There is no default: pass [`MarkdownStyle.Default`](#markdownstyledefault) explicitly if you only want the library defaults.

<PropInfo type="MarkdownStyle" required />

#### `content` {#markdowntheme-content-param}

The subtree the style applies to.

<PropInfo type="@Composable () -> Unit" required />

### `MarkdownTheme.style`

```kotlin
object MarkdownTheme {
  val style: MarkdownStyle
    @Composable @ReadOnlyComposable get
}
```

Reads the style currently in scope. This is what `EnrichedMarkdownText` uses as the default for its `style` parameter; read it yourself when you want to derive from the ambient style rather than replace it:

```kotlin
import androidx.compose.ui.graphics.Color
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.compose.MarkdownTheme

EnrichedMarkdownText(
  markdown = content,
  style = MarkdownTheme.style.merge { link { color = Color.Red } },
)
```

### `LocalMarkdownStyle`

```kotlin
val LocalMarkdownStyle: ProvidableCompositionLocal<MarkdownStyle>
```

The `staticCompositionLocalOf` behind `MarkdownTheme`, defaulting to [`MarkdownStyle.Default`](#markdownstyledefault). `MarkdownTheme` is a thin wrapper over providing it, so prefer the wrapper; reach for the composition local directly only when you need to provide it alongside other locals in one `CompositionLocalProvider`.

:::note
Because it is a **static** composition local, changing its value recomposes the whole subtree rather than only the readers. Provide a style that is stable across recompositions - see [Building styles cheaply](#building-styles-cheaply).
:::

## `markdownStyle`

```kotlin
fun markdownStyle(block: MarkdownStyleBuilder.() -> Unit): MarkdownStyle
```

Builds a style from the DSL. Not a composable, so you can - and usually should - hoist it to file scope:

```kotlin
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.sp
import com.swmansion.enriched.markdown.compose.markdownStyle

val AppMarkdownStyle = markdownStyle {
  paragraph { fontSize = 16.sp }
  link { color = Color(0xFF2563EB) }
}
```

Calling the same element block twice in one builder merges the two: properties set in the second call win, and the rest of the first call is kept. The result below has a 16 sp paragraph in `#1A1A1A`:

```kotlin
val Combined = markdownStyle {
  paragraph { fontSize = 16.sp }
  paragraph { color = Color(0xFF1A1A1A) }
}
```

Call it from a composable only when the values come from composition, such as `MaterialTheme` tokens - and in that case prefer [`rememberMarkdownStyle`](#remembermarkdownstyle).

#### `block` {#markdownstyle-block-param}

The DSL block. Each element function inside it (`paragraph`, `h1`, `link`, …) sets only the properties you assign; everything else keeps its default. See [Style properties](/android/api-reference/style-properties) for what each element takes.

<PropInfo type="MarkdownStyleBuilder.() -> Unit" required />

## `rememberMarkdownStyle`

```kotlin
@Composable
fun rememberMarkdownStyle(
  vararg keys: Any?,
  block: MarkdownStyleBuilder.() -> Unit,
): MarkdownStyle
```

Builds a style that tracks `MaterialTheme.colorScheme`: it remembers the result keyed on the color scheme plus any `keys` you pass, so the style is rebuilt when the color scheme changes - on a light/dark switch, for example - and reused otherwise.

```kotlin
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import com.swmansion.enriched.markdown.compose.MarkdownTheme
import com.swmansion.enriched.markdown.compose.rememberMarkdownStyle

@Composable
fun App() {
  MaterialTheme {
    MarkdownTheme(
      style = rememberMarkdownStyle {
        paragraph { color = MaterialTheme.colorScheme.onSurface }
        link { color = MaterialTheme.colorScheme.primary }
      },
    ) {
      AppContent()
    }
  }
}
```

The color scheme is the **only** thing tracked automatically. A block that reads `MaterialTheme.typography`, `MaterialTheme.shapes`, or any other value is not rebuilt when that value changes unless you pass it as a key. For static light/dark palettes with literal colors, hoist `markdownStyle` / `merge` to file scope instead - there is nothing to track.

#### `keys` {#remembermarkdownstyle-keys-param}

Extra values the block reads, compared the way `remember` compares its keys. The style is rebuilt when the color scheme or any key changes.

<PropInfo type="vararg Any?" default="none" />

```kotlin
val style = rememberMarkdownStyle(MaterialTheme.typography) {
  paragraph { fontSize = MaterialTheme.typography.bodyLarge.fontSize }
}
```

#### `block` {#remembermarkdownstyle-block-param}

The DSL block, the same as [`markdownStyle`](#markdownstyle)'s. It runs again only when the style is rebuilt.

<PropInfo type="MarkdownStyleBuilder.() -> Unit" required />

## `MarkdownStyle`

```kotlin
@Immutable
class MarkdownStyle {
  fun merge(block: MarkdownStyleBuilder.() -> Unit): MarkdownStyle
  fun merge(other: MarkdownStyle): MarkdownStyle
  operator fun plus(other: MarkdownStyle): MarkdownStyle

  companion object {
    val Default: MarkdownStyle
  }
}
```

An immutable, **layered** style. It holds a stack of override layers rather than a finished stylesheet, and the layers are flattened onto the library defaults only when a component resolves them.

### `MarkdownStyle.Default`

The empty style - no layers, so every element keeps its library default. It is what `LocalMarkdownStyle` starts out as, so an `EnrichedMarkdownText` with no theme at all renders with the library defaults - which are a fixed light palette (see [Dark mode](#dark-mode)).

### Dark mode {#dark-mode}

The library defaults are a **fixed light palette**: dark gray text, a blue link, light table and blockquote backgrounds. They do not follow the system theme, so with no style of your own the text is hard to read on a dark background. Supply the colors for the current theme yourself - from `MaterialTheme` tokens through [`rememberMarkdownStyle`](#remembermarkdownstyle), or as two hoisted variants picked by `isSystemInDarkTheme()`:

```kotlin
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.swmansion.enriched.markdown.compose.MarkdownTheme
import com.swmansion.enriched.markdown.compose.markdownStyle

val LightMarkdownStyle = markdownStyle {
  paragraph { color = Color(0xFF1A1A1A) }
}

val DarkMarkdownStyle = markdownStyle {
  paragraph { color = Color(0xFFE0E0E0) }
  link { color = Color(0xFF60A5FA) }
  code {
    color = Color(0xFFF9A8D4)
    backgroundColor = Color(0xFF3B1D2A)
    borderColor = Color(0xFF5B2A3E)
  }
  table {
    color = Color(0xFFE0E0E0)
    headerBackgroundColor = Color(0xFF1F2937)
    headerTextColor = Color(0xFFF9FAFB)
    rowEvenBackgroundColor = Color(0xFF111827)
    rowOddBackgroundColor = Color(0xFF1F2937)
    borderColor = Color(0xFF374151)
  }
}

@Composable
fun ThemedMarkdown(content: @Composable () -> Unit) {
  MarkdownTheme(
    style = if (isSystemInDarkTheme()) DarkMarkdownStyle else LightMarkdownStyle,
    content = content,
  )
}
```

Every element with a color of its own - inline code, blockquotes, tables, list markers, task lists - needs a dark value too. Code blocks are the exception: their default is already a dark block, and so is the palette of the optional [code highlighting](/android/guides/code-highlighting#styling). See [Style properties](/android/api-reference/style-properties) for each element's color properties.

### `MarkdownStyle.merge` {#markdownstylemerge}

```kotlin
fun merge(block: MarkdownStyleBuilder.() -> Unit): MarkdownStyle
fun merge(other: MarkdownStyle): MarkdownStyle
operator fun plus(other: MarkdownStyle): MarkdownStyle
```

Returns a new style with `block` **added as a layer on top**. It does not rebuild the style or replace what came before. Later layers win per property, and properties no layer sets keep their defaults. That makes `merge` the natural way to express variants:

```kotlin
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.sp
import com.swmansion.enriched.markdown.compose.markdownStyle

val Base = markdownStyle {
  paragraph { fontSize = 16.sp }
  link { textDecoration = TextDecoration.None }
}

val Light = Base.merge { paragraph { color = Color(0xFF1A1A1A) } }
val Dark = Base.merge { paragraph { color = Color(0xFFE0E0E0) } }
```

`Light` and `Dark` both keep the base font size and links without an underline (links are underlined by default).

To layer one whole style onto another, pass it to `merge` or use `+`. The right-hand style's layers go on top, and anything it leaves unset keeps the left-hand style's value:

```kotlin
val BrandColors = markdownStyle { link { color = Color(0xFF7C3AED) } }

val Branded = Base + BrandColors // same as Base.merge(BrandColors)
```

Two styles are equal when their layers are equal, so a hoisted style stays equal across recompositions and does not retrigger work downstream.

## How styles resolve

A `MarkdownStyle` is not a set of final pixel values. Resolving one means folding its layers onto `StyleConfig.default(context)` while converting Compose types to what the underlying view wants: `sp` and `Dp` become pixels at the current density, `Color` becomes a packed color int, and a `FontFamily` is resolved to a typeface.

That depends on the device configuration, so `EnrichedMarkdownText` re-resolves whenever the style, density, font resolver, or configuration changes, and it does the work **off the main thread**. The first frame paints with the library defaults and the resolved style lands immediately after.

### Building styles cheaply

Two consequences worth designing around:

- **Hoist your styles.** Building a style inside a composable body allocates a new `MarkdownStyle` on every recomposition. Equal layers still compare equal, so nothing re-resolves - but it is free to avoid, and `LocalMarkdownStyle` being a static composition local makes an unstable theme value expensive.
- **Use `rememberMarkdownStyle` when the values come from composition.** It is the supported way to read `MaterialTheme` tokens without rebuilding on every pass.

```kotlin
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.sp
import com.swmansion.enriched.markdown.compose.MarkdownTheme
import com.swmansion.enriched.markdown.compose.markdownStyle
import com.swmansion.enriched.markdown.compose.rememberMarkdownStyle

// Hoisted: allocated once for the whole process.
val AppMarkdownStyle = markdownStyle {
  paragraph { fontSize = 16.sp }
  link { color = Color(0xFF2563EB) }
}

@Composable
fun Root() {
  // Read from composition, so it has to be remembered rather than hoisted.
  val themed = rememberMarkdownStyle {
    paragraph { color = MaterialTheme.colorScheme.onSurface }
  }
  MarkdownTheme(style = themed) { Content() }
}
```

## See also

- [Style properties](/android/api-reference/style-properties) - the elements and properties you can set.
- [`EnrichedMarkdownText`](/android/api-reference/enriched-markdown-text) - the `style` parameter.
- [Custom fonts](/android/guides/custom-fonts) - how `FontFamily` values are resolved.
