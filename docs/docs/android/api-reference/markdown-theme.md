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
  style: MarkdownStyle = LocalMarkdownStyle.current,
  content: @Composable () -> Unit,
)
```

Provides `style` as the default for everything inside `content`. Themes nest, and the innermost one wins:

```kotlin
MarkdownTheme(style = appStyle) {
  HomeScreen()

  MarkdownTheme(style = compactStyle) {
    ChatBubble(markdown = message) // uses compactStyle
  }
}
```

Omitting `style` inherits the enclosing theme's style, so a bare `MarkdownTheme { }` at the root is a no-op that simply establishes the default.

### `MarkdownTheme.style`

```kotlin
object MarkdownTheme {
  val style: MarkdownStyle
    @Composable @ReadOnlyComposable get
}
```

Reads the style currently in scope. This is what `EnrichedMarkdownText` uses as the default for its `style` parameter; read it yourself when you want to derive from the ambient style rather than replace it:

```kotlin
EnrichedMarkdownText(
  markdown = content,
  style = MarkdownTheme.style.copy { link { color = Color.Red } },
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
val AppMarkdownStyle = markdownStyle {
  paragraph { fontSize = 16.sp }
  link { color = Color(0xFF2563EB) }
}
```

Call it from a composable only when the values come from composition, such as `MaterialTheme` tokens - and in that case prefer [`rememberMarkdownStyle`](#remembermarkdownstyle).

## `rememberMarkdownStyle`

```kotlin
@Composable
fun rememberMarkdownStyle(
  vararg keys: Any?,
  block: MarkdownStyleBuilder.() -> Unit,
): MarkdownStyle
```

Builds a style that tracks `MaterialTheme.colorScheme`: it remembers the result keyed on the color scheme plus any `keys` you pass, so the style is rebuilt when the Material theme changes - on a light/dark switch, for example - and reused otherwise.

```kotlin
MaterialTheme {
  MarkdownTheme(
    style = rememberMarkdownStyle {
      paragraph { color = MaterialTheme.colorScheme.onSurface }
      link { color = MaterialTheme.colorScheme.primary }
    },
  ) {
    NavHost(...)
  }
}
```

Pass extra `keys` for any other value the block reads, the way you would to `remember`. For static light/dark palettes with literal colors, hoist `markdownStyle` / `copy` to file scope instead - there is nothing to track.

## `MarkdownStyle`

```kotlin
@Immutable
class MarkdownStyle {
  fun copy(block: MarkdownStyleBuilder.() -> Unit): MarkdownStyle

  companion object {
    val Default: MarkdownStyle
  }
}
```

An immutable, **layered** style. It holds a stack of override layers rather than a finished stylesheet, and the layers are flattened onto the platform defaults only when a component resolves them.

### `MarkdownStyle.Default`

The empty style - no layers, so every element keeps its platform default. It is what `LocalMarkdownStyle` starts out as, which is why `EnrichedMarkdownText` renders sensibly with no theme at all.

### `MarkdownStyle.copy`

Returns a new style with `block` **added as a layer on top**; it does not rebuild the style or replace what came before. Later layers win per property, and properties no layer sets keep their defaults. That makes `copy` the natural way to express variants:

```kotlin
val Base = markdownStyle {
  paragraph { fontSize = 16.sp }
  link { underline = true }
}

val Light = Base.copy { paragraph { color = Color(0xFF1A1A1A) } }
val Dark = Base.copy { paragraph { color = Color(0xFFE0E0E0) } }
```

`Light` and `Dark` both keep the base font size and underlined links.

Two styles are equal when their layers are equal, so a hoisted style stays equal across recompositions and does not retrigger work downstream.

## How styles resolve

A `MarkdownStyle` is not a set of final pixel values. Resolving one means folding its layers onto `StyleConfig.default(context)` while converting Compose types to what the underlying view wants: `sp` and `Dp` become pixels at the current density, `Color` becomes a packed color int, and a `FontFamily` is resolved to a typeface.

That depends on the device configuration, so `EnrichedMarkdownText` re-resolves whenever the style, density, font resolver, or configuration changes, and it does the work **off the main thread**. The first frame paints with the platform defaults and the resolved style lands immediately after.

### Building styles cheaply

Two consequences worth designing around:

- **Hoist your styles.** Building a style inside a composable body allocates a new `MarkdownStyle` on every recomposition. Equal layers still compare equal, so nothing re-resolves - but it is free to avoid, and `LocalMarkdownStyle` being a static composition local makes an unstable theme value expensive.
- **Use `rememberMarkdownStyle` when the values come from composition.** It is the supported way to read `MaterialTheme` tokens without rebuilding on every pass.

## See also

- [Style properties](/android/api-reference/style-properties) - the elements and properties you can set.
- [`EnrichedMarkdownText`](/android/api-reference/enriched-markdown-text) - the `style` parameter.
- [Custom fonts](/android/guides/custom-fonts) - how `FontFamily` values are resolved.
