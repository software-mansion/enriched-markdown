---
sidebar_label: Style properties
sidebar_position: 3
---

# Style properties reference

Every Markdown element is styled through the `markdownStyle { }` DSL. This page lists each block you can open and the properties it takes. For how a style reaches a component and how layering works, see [`MarkdownTheme`](/android/api-reference/markdown-theme).

## The `markdownStyle` builder

A style is a set of **overrides**. Open only the blocks you want to change; everything else keeps the default listed below.

```kotlin
val AppMarkdownStyle = markdownStyle {
  paragraph {
    fontSize = 16.sp
    lineHeight = 26.sp
  }
  h1 { color = Color(0xFF111827) }
  codeBlock {
    backgroundColor = Color(0xFF1F2937)
    cornerRadius = 8.dp
  }
}
```

The available blocks:

| Block | Applies to |
| --- | --- |
| `paragraph` | Body text |
| `h1` … `h6` | Headings, each level styled independently |
| `blockquote` | Block quotes, plus `admonitions { }` for GitHub alerts |
| `list` | Ordered and unordered lists, including their markers |
| `taskList` | Task list checkboxes |
| `codeBlock` | Fenced code blocks |
| `code` | Inline code |
| `link` | Links and autolinks |
| `strong` | Bold text |
| `emphasis` | Italic text |
| `strikethrough` | Struck-through text |
| `underline` | Underlined text (needs `Md4cFlags(underline = true)`) |
| `superscript` | Superscript (needs `Md4cFlags(superscript = true)`) |
| `subscript` | Subscript (needs `Md4cFlags(subscript = true)`) |
| `image` | Block images |
| `inlineImage` | Inline images |
| `thematicBreak` | Horizontal rules |

Values use Compose types throughout: `Color`, `Dp` for lengths, `TextUnit` (`sp`) for text metrics, plus `FontFamily`, `FontWeight`, and `FontStyle`.

## Style inheritance

**Block styles** are self-contained: a `paragraph` and an `h1` each carry their own font size, color, line height, and margins, and one never falls back to the other.

**Inline styles** are partial by design. `strong`, `emphasis`, `strikethrough`, `underline`, and `link` set only the handful of properties that make them distinct, and everything else - size, line height, and by default the color - is inherited from whatever block the text sits in. Bold text in a heading is therefore heading-sized; bold text in a paragraph is paragraph-sized, with no configuration.

That is why several inline properties default to "inherited" rather than a value. Setting one pins it everywhere the element appears:

```kotlin
markdownStyle {
  strong { color = Color.Red } // bold is red in headings, paragraphs, quotes alike
}
```

Leave it unset to keep bold following its surroundings.

## Layering with `copy`

`MarkdownStyle.copy { }` adds a layer on top of an existing style rather than replacing it, so variants stay expressed as differences:

```kotlin
val Base = markdownStyle {
  paragraph { fontSize = 16.sp }
  link { underline = true }
}

val Compact = Base.copy { paragraph { marginBottom = 8.dp } }
```

See [`MarkdownStyle.copy`](/android/api-reference/markdown-theme#markdownstylecopy) for the details.

## Dark mode

The defaults below are a **light palette** - the library does not swap them automatically. Supply the colors for the current theme yourself, either from `MaterialTheme` tokens:

```kotlin
MarkdownTheme(
  style = rememberMarkdownStyle {
    paragraph { color = MaterialTheme.colorScheme.onSurface }
    link { color = MaterialTheme.colorScheme.primary }
    codeBlock { backgroundColor = MaterialTheme.colorScheme.surfaceVariant }
  },
) {
  Content()
}
```

…or as two hoisted variants of one base style, picked by `isSystemInDarkTheme()`:

```kotlin
MarkdownTheme(style = if (isSystemInDarkTheme()) DarkMarkdownStyle else LightMarkdownStyle) {
  Content()
}
```

Use [`rememberMarkdownStyle`](/android/api-reference/markdown-theme#remembermarkdownstyle) whenever the block reads `MaterialTheme`, so the style rebuilds when the color scheme changes.

## Property reference

### Block styles (`paragraph`, `h1`-`h6`)

Shared by `paragraph` and every heading level.

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `fontSize` | `TextUnit` | `16.sp` | Text size |
| `fontFamily` | `FontFamily` | `FontFamily.SansSerif` | Typeface |
| `fontWeight` | `FontWeight` | `FontWeight.Normal` | Weight |
| `color` | `Color` | `#1F2937` | Text color |
| `lineHeight` | `TextUnit` | `26.sp` | Line height |
| `marginTop` | `Dp` | `0.dp` | Space above the block |
| `marginBottom` | `Dp` | `16.dp` | Space below the block |
| `textAlign` | `TextAlignment` | `TextAlignment.AUTO` | Alignment |

The defaults above are the `paragraph` values. Each heading level overrides size, line height, color, and bottom margin:

| Block | `fontSize` | `lineHeight` | `color` | `marginBottom` |
| --- | --- | --- | --- | --- |
| `h1` | `30.sp` | `38.sp` | `#111827` | `8.dp` |
| `h2` | `24.sp` | `32.sp` | `#111827` | `8.dp` |
| `h3` | `20.sp` | `28.sp` | `#111827` | `8.dp` |
| `h4` | `18.sp` | `26.sp` | `#111827` | `8.dp` |
| `h5` | `16.sp` | `24.sp` | `#374151` | `8.dp` |
| `h6` | `14.sp` | `22.sp` | `#4B5563` | `8.dp` |

### `blockquote`

Carries the full set of block properties, with its own defaults, plus the quote decoration.

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `fontSize` | `TextUnit` | `16.sp` | Text size |
| `fontFamily` | `FontFamily` | `FontFamily.SansSerif` | Typeface |
| `fontWeight` | `FontWeight` | `FontWeight.Normal` | Weight |
| `color` | `Color` | `#4B5563` | Text color |
| `lineHeight` | `TextUnit` | `26.sp` | Line height |
| `marginTop` | `Dp` | `0.dp` | Space above |
| `marginBottom` | `Dp` | `16.dp` | Space below |
| `borderColor` | `Color` | `#D1D5DB` | Left accent bar color |
| `borderWidth` | `Dp` | `3.dp` | Left accent bar width |
| `gapWidth` | `Dp` | `16.dp` | Gap between the bar and the text |
| `backgroundColor` | `Color` | `#F9FAFB` | Background fill |

### `admonitions` {#admonitions}

A blockquote opening with `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, or `> [!CAUTION]` renders as a themed callout with a tinted icon and a bold title. Admonitions nest under `blockquote` because they **inherit its geometry** - border width, gap, font, and spacing all come from the block above - and override only colors.

```kotlin
markdownStyle {
  blockquote {
    admonitions {
      warning {
        color = Color(0xFF9A6700)
        backgroundColor = Color(0xFFFFF8C5)
      }
      caution { color = Color(0xFFCF222E) }
    }
  }
}
```

Each of `note`, `tip`, `important`, `warning`, and `caution` takes:

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `color` | `Color` | Per type, below | Tints the accent bar, the title, and the icon |
| `backgroundColor` | `Color` | Unset | Background fill. Unset means the callout is drawn unfilled |

Default `color` per type, matching GitHub's alert palette:

| Type | Default color |
| --- | --- |
| `note` | `#0969DA` |
| `tip` | `#1A7F37` |
| `important` | `#8250DF` |
| `warning` | `#9A6700` |
| `caution` | `#CF222E` |

Types you omit keep their defaults, and within a type an omitted property falls back the same way. The title is always bold, whatever `fontWeight` the blockquote carries.

:::note
Requires [`Md4cFlags(admonitions = true)`](/android/api-reference/enriched-markdown-text#admonitions), which is **off** by default. Without it the marker is literal text in an ordinary quote and these styles do not apply.
:::

### `list`

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `fontSize` | `TextUnit` | `16.sp` | Text size |
| `fontFamily` | `FontFamily` | `FontFamily.SansSerif` | Typeface |
| `fontWeight` | `FontWeight` | `FontWeight.Normal` | Weight |
| `color` | `Color` | `#1F2937` | Text color |
| `lineHeight` | `TextUnit` | `26.sp` | Line height |
| `marginTop` | `Dp` | `0.dp` | Space above the list |
| `marginBottom` | `Dp` | `16.dp` | Space below the list |
| `bulletColor` | `Color` | `#6B7280` | Unordered list bullet color |
| `bulletSize` | `Dp` | `6.dp` | Unordered list bullet size |
| `markerColor` | `Color` | `#6B7280` | Ordered list number color |
| `markerFontWeight` | `FontWeight` | `FontWeight.Medium` (500) | Ordered list number weight |
| `markerMinWidth` | `Dp` | `0.dp` | Minimum width reserved for the marker column |
| `gapWidth` | `Dp` | `12.dp` | Gap between the marker and the text |
| `marginLeft` | `Dp` | `24.dp` | Indent applied per nesting level |

### `taskList`

Styles the checkbox drawn for `- [ ]` and `- [x]` items. The item's text is styled by `list`.

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `checkedColor` | `Color` | `#2196F3` | Fill of a checked box |
| `borderColor` | `Color` | `#9E9E9E` | Border of an unchecked box |
| `checkboxSize` | `Dp` | `14.dp` | Box size |
| `checkboxBorderRadius` | `Dp` | `3.dp` | Box corner radius |
| `checkmarkColor` | `Color` | `#FFFFFF` | Checkmark color |
| `checkedTextColor` | `Color` | Unset | Text color of a checked item. Unset keeps the `list` color |
| `checkedStrikethrough` | `Boolean` | `false` | Strike through the text of a checked item |

### `codeBlock`

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `fontSize` | `TextUnit` | `14.sp` | Text size |
| `fontFamily` | `FontFamily` | `FontFamily.Monospace` | Typeface |
| `fontWeight` | `FontWeight` | `FontWeight.Normal` | Weight |
| `color` | `Color` | `#F3F4F6` | Text color |
| `lineHeight` | `TextUnit` | `22.sp` | Line height |
| `marginTop` | `Dp` | `0.dp` | Space above |
| `marginBottom` | `Dp` | `16.dp` | Space below |
| `backgroundColor` | `Color` | `#1F2937` | Background fill |
| `borderColor` | `Color` | `#374151` | Border color |
| `borderWidth` | `Dp` | `1.dp` | Border width |
| `cornerRadius` | `Dp` | `8.dp` | Corner radius |
| `padding` | `Dp` | `16.dp` | Inner padding |

### `code`

Inline code. `fontSize` and `fontFamily` are unset by default, so inline code takes the size of the text around it.

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `fontFamily` | `FontFamily` | Inherited | Typeface |
| `fontSize` | `TextUnit` | Inherited | Text size |
| `color` | `Color` | `#E01E5A` | Text color |
| `backgroundColor` | `Color` | `#FDF2F4` | Background fill |
| `borderColor` | `Color` | `#F8D7DA` | Border color |

### `link`

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `fontFamily` | `FontFamily` | Inherited | Typeface |
| `color` | `Color` | `#2563EB` | Text color |
| `underline` | `Boolean` | `true` | Underline the link text |
| `backgroundColor` | `Color` | `Color.Transparent` | Background fill |

### `strong`

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `fontFamily` | `FontFamily` | Inherited | Typeface |
| `fontWeight` | `FontWeight` | `FontWeight.Bold` | Weight |
| `color` | `Color` | Inherited | Text color |

### `emphasis`

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `fontFamily` | `FontFamily` | Inherited | Typeface |
| `fontStyle` | `FontStyle` | `FontStyle.Italic` | Slant |
| `color` | `Color` | Inherited | Text color |

### `strikethrough`

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `color` | `Color` | Inherited | Text color |

### `underline`

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `color` | `Color` | Inherited | Text color |

### `superscript`

Takes unitless `Float`s rather than `Dp`/`sp`, because both are expressed relative to the surrounding text.

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `fontScale` | `Float` | `0.65f` | Text size as a fraction of the surrounding text |
| `baselineOffsetScale` | `Float` | `0.35f` | Baseline shift **up**, as a fraction of text size |

### `subscript`

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `fontScale` | `Float` | `0.65f` | Text size as a fraction of the surrounding text |
| `baselineOffsetScale` | `Float` | `0.2f` | Baseline shift **down**, as a fraction of text size |

### `image`

Block images - an image that is the whole paragraph.

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `height` | `Dp` | `200.dp` | Rendered height; width follows the container |
| `borderRadius` | `Dp` | `8.dp` | Corner radius |
| `marginTop` | `Dp` | `0.dp` | Space above |
| `marginBottom` | `Dp` | `16.dp` | Space below |

### `inlineImage`

An image sitting inside a line of text, sized to the line rather than the container.

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `size` | `Dp` | `20.dp` | Width and height of the inline image |

### `thematicBreak`

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `color` | `Color` | `#E5E7EB` | Rule color |
| `height` | `Dp` | `1.dp` | Rule thickness |
| `marginTop` | `Dp` | `24.dp` | Space above |
| `marginBottom` | `Dp` | `24.dp` | Space below |
