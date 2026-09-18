---
sidebar_label: Custom fonts
sidebar_position: 2
---

# Custom fonts

Every style block that renders text takes a `fontFamily`, so you can set the typeface globally, per element, or both. This guide covers what you can pass, how it is resolved, and the two limits worth knowing before you design around it.

## System families

Compose's built-in families work as you would expect, and cost nothing to resolve - they map straight onto the platform's own family names:

```kotlin
markdownStyle {
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

val Inter = FontFamily(Font(R.font.inter_regular))

val AppMarkdownStyle = markdownStyle {
  paragraph { fontFamily = Inter }
  h1 { fontFamily = Inter }
}
```

The font resource is loaded once and cached for the life of the process, so reusing the same `FontFamily` across blocks and components costs nothing extra.

Downloadable fonts and any other `FontFamily` your app can resolve also work: whatever Compose's own font resolver returns is used.

## Per-element fonts

`fontFamily` is available on `paragraph`, every heading level, `blockquote`, `list`, `codeBlock`, `code`, `link`, `strong`, and `emphasis` - so a display face for headings over a text face for body copy is a two-line style:

```kotlin
val AppMarkdownStyle = markdownStyle {
  paragraph { fontFamily = Inter }
  h1 { fontFamily = Playfair }
  h2 { fontFamily = Playfair }
}
```

Inline blocks like `strong` inherit the font of the block they sit in unless you set one, so bold text inside a `Playfair` heading stays Playfair without being told to.

## Two limits worth knowing

### One file per family

A family is resolved down to a **single typeface**. If you declare a multi-file family:

```kotlin
val Inter = FontFamily(
  Font(R.font.inter_regular, FontWeight.Normal),
  Font(R.font.inter_bold, FontWeight.Bold), // not selected
)
```

…the first font resource in the family is the one that gets used, and the others are ignored. Bold and italic are then derived from that single face rather than picked from your file set.

In practice: declare the family with the **regular** weight, and let weight and slant be derived. If you need a specific weight to come from a specific file, declare it as its own family and assign it to the blocks that should use it.

### Weight fidelity depends on the OS version

On Android 9 (API 28) and newer, a numeric `fontWeight` is applied to the resolved typeface with reasonable fidelity. On older versions the platform only understands two weights, so anything `600` or heavier renders bold and everything lighter renders regular - a `FontWeight.Medium` heading will look regular on Android 7 and 8.

Design your hierarchy so it still reads with only two weights available, or carry the distinction with size and color as well as weight.

## Fonts follow the theme

`fontFamily` is an ordinary style property, so it layers and overrides like any other - see [`MarkdownStyle.copy`](/android/api-reference/markdown-theme#markdownstylecopy). If your font choice depends on something read from composition, build the style with [`rememberMarkdownStyle`](/android/api-reference/markdown-theme#remembermarkdownstyle) so it is rebuilt when that changes.
