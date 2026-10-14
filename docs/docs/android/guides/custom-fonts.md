---
sidebar_label: Custom fonts
sidebar_position: 2
---

# Custom fonts

Every style block that renders text takes a `fontFamily`, so you can set the typeface globally, per element, or both. This guide covers what you can pass, how it is resolved, and the limits worth knowing before you design around it.

## System families

Compose's built-in families work as you would expect, and cost nothing to resolve - they map straight onto the platform's own family names:

```kotlin
import androidx.compose.ui.text.font.FontFamily
import com.swmansion.enriched.markdown.compose.markdownStyle

val SerifMarkdownStyle = markdownStyle {
  paragraph { fontFamily = FontFamily.Serif }
  codeBlock { fontFamily = FontFamily.Monospace }
}
```

`FontFamily.Default` and `FontFamily.SansSerif` both resolve to the system sans-serif, `Serif` to the system serif, `Monospace` to the system monospace, and `Cursive` to the system cursive.

By default `code` and `codeBlock` already use monospace and everything else uses sans-serif, so you only need to set these when you want something different.

## Bundled fonts

Drop a font file into `res/font/` and reference it the standard Compose way:

```kotlin
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import com.swmansion.enriched.markdown.compose.markdownStyle

val Inter = FontFamily(Font(R.font.inter_regular))

val AppMarkdownStyle = markdownStyle {
  paragraph { fontFamily = Inter }
  h1 { fontFamily = Inter }
}
```

The font resource is loaded once and cached for the life of the process, so reusing the same `FontFamily` across blocks and components costs nothing extra.

Any other `FontFamily` your app can resolve also works: whatever Compose's own font resolver returns is used.

:::caution
The family is resolved once, when the style is resolved, and the result is not updated later. A [downloadable font](https://developer.android.com/develop/ui/compose/text/fonts#downloadable-fonts) that is still loading at that moment renders with the fallback face, and keeps it until the style is resolved again (a style, density, or configuration change). Bundle the font in `res/font/` when it has to show on first render.
:::

## Per-element fonts

`fontFamily` is available on `paragraph`, every heading level, `blockquote`, `list`, `codeBlock`, `code`, `link`, `strong`, `emphasis`, and `table` - so a display face for headings over a text face for body copy is a two-line style:

```kotlin
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import com.swmansion.enriched.markdown.compose.markdownStyle

val Inter = FontFamily(Font(R.font.inter_regular))
val Playfair = FontFamily(Font(R.font.playfair_display_regular))

val AppMarkdownStyle = markdownStyle {
  paragraph { fontFamily = Inter }
  h1 { fontFamily = Playfair }
  h2 { fontFamily = Playfair }
}
```

Inline elements like `strong`, `emphasis`, and `link` inherit the font of the block they sit in unless you set one, so bold text inside a `Playfair` heading stays Playfair without being told to. Inline `code` is the exception: it does **not** inherit, and uses the system monospace unless you set `code { fontFamily = … }`.

Tables take two families: `fontFamily` for body cells and `headerFontFamily` for the header row.

```kotlin
val TableMarkdownStyle = markdownStyle {
  table {
    fontFamily = Inter
    headerFontFamily = Playfair
  }
}
```

With no `headerFontFamily`, header cells use the body family in bold (or the system bold face if neither is set). A `headerFontFamily` you set is used at regular weight, so point it at a bold file if you want bold headers.

## Limits worth knowing

### One file per family

A family is resolved down to a **single typeface**. If you declare a multi-file family:

```kotlin
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight

val Inter = FontFamily(
  Font(R.font.inter_regular, FontWeight.Normal),
  Font(R.font.inter_bold, FontWeight.Bold), // not selected
)
```

…the **first** font resource in the list is the one that gets used, and the others are ignored. The `FontWeight` and `FontStyle` you tag each `Font` with play no part in the choice - list the bold file first and every element renders from the bold file. Bold and italic are then derived from that single face rather than picked from your file set.

In practice: declare the family with the **regular** file first (or only), and let weight and slant be derived. If you need a specific weight to come from a specific file, declare it as its own family and assign it to the blocks that should use it.

### Only four weights

A block's `fontWeight` is rounded down to one of four weights before it reaches the typeface:

| You set                                                 | Renders as |
| ------------------------------------------------------- | ---------- |
| `W100`-`W400` (`Thin`, `ExtraLight`, `Light`, `Normal`) | 400        |
| `W500` (`Medium`)                                       | 500        |
| `W600` (`SemiBold`)                                     | 600        |
| `W700`-`W900` (`Bold`, `ExtraBold`, `Black`)            | 700        |

So there is no light text and nothing heavier than bold: `FontWeight.Light` renders regular and `FontWeight.Black` renders as plain bold. The weight is applied to the single face the family resolved to, and the platform uses the closest face it has - so with one custom file, 500 and 600 can look the same as 400 or 700.

On Android 8.1 (API 27) and older the platform only understands two weights, so 600 and 700 render bold and 400 and 500 render regular - a `FontWeight.Medium` heading looks regular there.

Design your hierarchy so it still reads with only two weights available, or carry the distinction with size and color as well as weight.

### `strong` is always bold

`strong { fontWeight = … }` does not pick a weight. Without a `strong` `fontFamily`, bold text is always the standard bold of the surrounding face. With one, any weight from `FontWeight.Medium` up still renders bold, and only a weight below `Medium` turns bold off. To change how strong text looks, change its `fontFamily` or `color`.

## Fonts follow the theme

`fontFamily` is an ordinary style property, so it layers and overrides like any other - see [`MarkdownStyle.merge`](/android/api-reference/markdown-theme#markdownstylemerge). If your font choice depends on something read from composition, build the style with [`rememberMarkdownStyle`](/android/api-reference/markdown-theme#remembermarkdownstyle) so it is rebuilt when that changes.
