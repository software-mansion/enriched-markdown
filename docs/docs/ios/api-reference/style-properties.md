---
sidebar_label: Style properties
sidebar_position: 3
---

# Style properties reference

Every Markdown element is styled by naming it in a `MarkdownTheme { }` builder and chaining modifiers onto it. This page lists each element and the modifiers it takes. For how a theme reaches a view and how layering works, see [`MarkdownTheme`](/ios/api-reference/markdown-theme).

## The builder

A theme is a set of **overrides**. Name only the elements you want to change; everything else keeps the default listed below.

```swift
let appTheme = MarkdownTheme {
  Paragraph()
    .font(.body)
    .lineHeight(26)

  Heading(1).foregroundStyle(.primary)

  CodeBlock()
    .background(Color(.secondarySystemBackground))
    .cornerRadius(8)
}
```

The elements:

| Element | Applies to |
| --- | --- |
| [`Paragraph()`](#paragraph) | Body text |
| [`Heading(1)` … `Heading(6)`](#heading) | Headings, each level styled independently |
| [`Blockquote()`](#blockquote) | Block quotes, and the geometry of admonitions |
| [`Admonition(.note)`](#admonition) | One GitHub alert type's colors |
| [`List()`](#list) | Ordered and unordered lists, including their markers |
| [`TaskList()`](#tasklist) | Task list checkboxes |
| [`Table()`](#table) | GFM tables |
| [`CodeBlock()`](#codeblock) | Fenced code blocks |
| [`Code()`](#code) | Inline code |
| [`Link()`](#link) | Links and autolinks |
| [`Strong()`](#strong-emphasis-strikethrough) | Bold text |
| [`Emphasis()`](#strong-emphasis-strikethrough) | Italic text |
| [`Strikethrough()`](#strong-emphasis-strikethrough) | Struck-through text |
| [`Underline()`](#underline) | Underlined text (needs `Md4cFlags(underline: true)`) |
| [`Superscript()` / `Subscript()`](#superscript--subscript) | Raised and lowered text (needs the matching option) |
| [`Highlight()`](#highlight) | Highlighted text (needs `Md4cFlags(highlight: true)`) |
| [`Spoiler()`](#spoiler) | The overlay concealing `\|\|spoiler\|\|` text |
| [`BlockImage()`](#blockimage) | Images alone in a paragraph |
| [`InlineImage()`](#inlineimage) | Images sharing a line with text |
| [`ThematicBreak()`](#thematicbreak) | Horizontal rules |

`MathBlock()` and `InlineMath()` come with the `EnrichedMarkdownLaTeX` product - see [LaTeX math](/ios/guides/latex-math#styling).

## Shared modifiers {#shared-modifiers}

The elements that carry text - `Paragraph`, `Heading`, `Blockquote`, `List`, `Table`, `Code`, `Link`, `Strong`, `Emphasis`, `Strikethrough`, `Underline`, `Highlight` - accept this base set:

| Modifier | Effect |
| --- | --- |
| `.font(_ font: Font)` | A SwiftUI text style, in any spelling (`.body`, `.system(.title)`, `.system(.title, design: .serif, weight: .bold)`). Scales with Dynamic Type |
| `.fontSize(_ size: CGFloat, weight: Font.Weight = .regular)` | A **fixed** system size |
| `.fontFamily(_ name: String, size: CGFloat)` | A registered font family at a **fixed** size |
| `.bold()` | Bold weight, over whatever font a lower layer set |
| `.fontDesign(_ design: Font.Design)` | `.default`, `.serif`, `.rounded`, `.monospaced` - system fonts only |
| `.foregroundStyle(_ color: Color)` | Text color |
| `.foregroundStyle(_ semantic:)` | `.primary`, `.secondary`, `.tertiary`, `.quaternary`, `.tint` - adapt to light and dark |
| `.marginTop(_ value: CGFloat)` | Space above the block |
| `.marginBottom(_ value: CGFloat)` | Space below the block |
| `.lineHeight(_ value: CGFloat)` | Line height in points |
| `.textAlignment(_ alignment: TextAlignment)` | `.leading`, `.center`, `.trailing` |

```swift
MarkdownTheme {
  Paragraph()
    .font(.body)
    .foregroundStyle(.primary)
    .lineHeight(26)
    .marginBottom(16)

  Heading(2)
    .fontFamily("Inter-SemiBold", size: 24)   // fixed size, no Dynamic Type
    .textAlignment(.leading)
}
```

`.bold()` and `.fontDesign(_:)` **layer** over the font a lower theme layer set, so `Heading(1).bold()` on its own bolds the default heading font rather than replacing it.

The elements that are not text blocks take their own modifiers instead, listed in their sections below: [`CodeBlock()`](#codeblock), [`TaskList()`](#tasklist), [`Admonition()`](#admonition), [`Spoiler()`](#spoiler), [`BlockImage()`](#blockimage), [`InlineImage()`](#inlineimage), [`ThematicBreak()`](#thematicbreak), and [`Superscript()` / `Subscript()`](#superscript--subscript).

Background modifiers - `.background(_:)` and its alias `.backgroundStyle(_:)` - are available on `Code`, `CodeBlock`, `Blockquote`, `Admonition`, `Highlight`, and `Spoiler` only; a paragraph or heading has no fill.

:::caution
`.fontSize(_:weight:)` and `.fontFamily(_:size:)` take a point size, which **opts the element out of Dynamic Type**. Use `.font(.body)` and its siblings unless you have a reason not to; see [Custom fonts](/ios/guides/custom-fonts).
:::

:::note
`.font(_:)` reads back a SwiftUI **text style** only. A point-sized or otherwise modified `Font` - `.system(size: 17)`, `.custom(_:size:)`, `.weight()`, `.italic()` - cannot be inspected through public API, so passing one logs a runtime warning and renders as `.body`. Use `.fontSize(_:weight:)` and `.fontFamily(_:size:)` for those.
:::

## Style inheritance

**Block elements** are self-contained: `Paragraph()` and `Heading(1)` each carry their own font, color, line height, and margins, and one never falls back to the other.

**Inline elements** are partial by design. `Strong`, `Emphasis`, `Strikethrough`, `Underline`, `Code`, and `Link` set only what makes them distinct, and everything else - size, line height, and by default the color - comes from whichever block the text sits in. Bold text in a heading is therefore heading-sized; bold text in a paragraph is paragraph-sized, with no configuration.

That is why several inline modifiers below are documented as *inherited* rather than as a value. Setting one pins it everywhere the element appears:

```swift
MarkdownTheme {
  Strong().foregroundStyle(.red)  // bold is red in headings, paragraphs, quotes alike
}
```

Leave it unset to keep bold following its surroundings.

## Dark mode and Dynamic Type {#adaptive-values}

`MarkdownTheme.default` is built from semantic colors and system text styles, so it adapts to both the appearance and the text size on its own. A theme you write adapts only as far as the values you give it do:

| You write | What adapts |
| --- | --- |
| `.font(.body)`, `.font(.largeTitle)`, any SwiftUI text style | Size follows **Dynamic Type** |
| `.fontSize(17)`, `.fontFamily("Inter", size: 17)` | Nothing - a fixed point size |
| `.foregroundStyle(.primary)`, `.secondary`, `.tint`, `.quaternary` | Light and dark, automatically |
| `.foregroundStyle(Color(.label))`, or any dynamic system `Color` | Light and dark, automatically |
| `.foregroundStyle(Color(red: …, green: …, blue: …))` | Nothing - a fixed color |

Values resolve when a view renders, not when the theme is built, so a theme hoisted to a `let` at file scope adapts exactly as well as one rebuilt in `body`. For scaling a custom family along with the text size, see [Custom fonts](/ios/guides/custom-fonts).

### Capping or disabling text scaling {#text-scaling}

There is no font-scaling option on the view. `EnrichedMarkdownText` reads `dynamicTypeSize` from the environment and resolves against it, so SwiftUI's own modifier is the control - applied to the view or anywhere above it:

```swift
EnrichedMarkdownText(content)
  .dynamicTypeSize(...DynamicTypeSize.accessibility1)  // cap how far it scales

EnrichedMarkdownText(content)
  .dynamicTypeSize(.large)                             // pin one size
```

Capping is almost always the better of the two: it keeps the document readable at large text sizes without letting a long heading run off the screen.

## Property reference

Each element below lists the modifiers it adds on top of the [shared modifiers](#shared-modifiers), or - where it takes none of those - its whole surface. A default of *unset* means the property falls through to whatever a lower theme layer set, or to the renderer's own fallback.

### `Paragraph()` {#paragraph}

Body text. Takes the [shared modifiers](#shared-modifiers) and adds none of its own; no background.

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.font(_:)` | `Font` | `.body` | Text style for the block |
| `.foregroundStyle(_:)` | `Color \| semantic` | `.primary` | Text color |
| `.lineHeight(_:)` | `CGFloat` | `26` | Line height in points |
| `.marginTop(_:)` | `CGFloat` | unset | Space above the block |
| `.marginBottom(_:)` | `CGFloat` | `16` | Space below the block |
| `.textAlignment(_:)` | `TextAlignment` | unset | `.leading`, `.center`, or `.trailing` |

```swift
MarkdownTheme {
  Paragraph()
    .font(.body)
    .lineHeight(28)
    .marginBottom(20)
}
```

### `Heading(_ level: Int)` {#heading}

One heading level, 1 through 6. The level is clamped into that range, so `Heading(9)` styles `h6`. Every level takes the same [shared modifiers](#shared-modifiers) and only the defaults differ; no background.

| Level | Font | Color | Margin bottom |
| --- | --- | --- | --- |
| `Heading(1)` | `.largeTitle`, bold | `.primary` | `8` |
| `Heading(2)` | `.title`, bold | `.primary` | `8` |
| `Heading(3)` | `.title2`, bold | `.primary` | `8` |
| `Heading(4)` | `.title3`, bold | `.primary` | `8` |
| `Heading(5)` | `.headline` | `.primary` | `8` |
| `Heading(6)` | `.subheadline` | `.secondary` | `8` |

```swift
MarkdownTheme {
  Heading(1)
    .font(.largeTitle)
    .bold()
    .marginTop(24)
    .marginBottom(12)

  Heading(2).font(.title2).foregroundStyle(.secondary)
}
```

### `Blockquote()` {#blockquote}

Block quotes, and the geometry every admonition inherits. Takes the [shared modifiers](#shared-modifiers) plus:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.borderColor(_:)` | `Color \| semantic` | `.tint` | Color of the accent bar down the side. An [`Admonition()`](#admonition) tint overrides it for that alert type |
| `.borderWidth(_:)` | `CGFloat` | `3` | Thickness of that bar |
| `.gapWidth(_:)` | `CGFloat` | `16` | Space between the bar and the quoted text |
| `.background(_:)` | `Color \| semantic` | unset | Fill behind the quote |

```swift
MarkdownTheme {
  Blockquote()
    .borderColor(.secondary)
    .borderWidth(4)
    .gapWidth(12)
    .background(Color(.secondarySystemBackground))
}
```

Font defaults to `.body`, color to `.secondary`, and margin bottom to `16`. Nested quotes each draw their own bar, so depth stays visible.

### `Admonition(_ type: AdmonitionType)` {#admonition}

Colors for **one** GitHub alert type. Geometry, font, and spacing come from [`Blockquote()`](#blockquote) - an admonition only recolors it, so these two modifiers are the whole surface:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.foregroundStyle(_:)` | `Color \| semantic` | per type, see below | Tints the accent bar, the icon, and the title together |
| `.background(_:)` | `Color \| semantic` | unset - no fill | Fill behind the callout |

```swift
MarkdownTheme {
  Admonition(.warning)
    .foregroundStyle(.orange)
    .background(Color.orange.opacity(0.12))

  Admonition(.note)
    .foregroundStyle(.blue)
}
```

The five types and their default tints, GitHub's palette:

| Type | Marker | Tint |
| --- | --- | --- |
| `.note` | `> [!NOTE]` | `#0969DA` |
| `.tip` | `> [!TIP]` | `#1A7F37` |
| `.important` | `> [!IMPORTANT]` | `#8250DF` |
| `.warning` | `> [!WARNING]` | `#9A6700` |
| `.caution` | `> [!CAUTION]` | `#CF222E` |

A type you never style falls back to the blockquote's border color. Admonitions need `Md4cFlags(admonitions: true)`; see [Parser extensions](/ios/guides/parser-extensions#admonitions).

### `List()` {#list}

Ordered and unordered lists, and their markers. Takes the [shared modifiers](#shared-modifiers) - which style the item **text** - plus:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.bulletColor(_:)` | `Color \| semantic` | `.secondary` | The dot drawn for an unordered item |
| `.bulletSize(_:)` | `CGFloat` | `6` | Diameter of that dot, in points |
| `.markerColor(_:)` | `Color \| semantic` | `.secondary` | The `1.` `2.` `3.` of an ordered item |
| `.markerMinWidth(_:)` | `CGFloat` | `0` | Minimum width reserved for the marker column, so numbers past `9.` do not shift the text. `0` sizes the column to each marker |
| `.gapWidth(_:)` | `CGFloat` | `12` | Space between the marker and the item text. Clamped to a minimum of `4` |
| `.marginLeft(_:)` | `CGFloat` | `24` | Indent added per nesting level |

```swift
MarkdownTheme {
  List()
    .bulletColor(.tint)
    .bulletSize(8)
    .markerColor(.tint)
    .markerMinWidth(24)   // keeps text aligned past "9."
    .gapWidth(10)
    .marginLeft(20)
}
```

Font defaults to `.body`, color to `.primary`, and margin bottom to `16`.

### `TaskList()` {#tasklist}

The checkboxes of `- [ ]` / `- [x]` items, and what a checked item's text looks like. Item text itself is styled by [`List()`](#list), so this element takes **only** these modifiers - no font, no margins:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.checkboxSize(_:)` | `CGFloat` | `14` | Side length of the box, in points |
| `.checkboxBorderRadius(_:)` | `CGFloat` | `3` | Corner radius of the box |
| `.checkedColor(_:)` | `Color \| semantic` | `.tint` | Fill of a checked box |
| `.borderColor(_:)` | `Color \| semantic` | `.secondary` | Outline of an unchecked box |
| `.checkmarkColor(_:)` | `Color \| semantic` | `.white` | The tick inside a checked box |
| `.checkedTextColor(_:)` | `Color \| semantic` | unset | Recolors the text of a checked item - the usual "done, dimmed" treatment. Unset leaves it the same as an unchecked item |
| `.checkedStrikethrough(_ enabled: Bool = true)` | `Bool` | `false` | Strikes through the text of a checked item |

```swift
MarkdownTheme {
  TaskList()
    .checkboxSize(18)
    .checkboxBorderRadius(9)      // a circle, at half the size
    .checkedColor(.green)
    .checkedTextColor(.secondary)
    .checkedStrikethrough()
}
```

The last two apply the moment the reader toggles a box, not only on the first render.

### `Table()` {#table}

GFM tables. Takes the [shared modifiers](#shared-modifiers) for the **cell** text, plus:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.headerFontFamily(_ name: String, size: CGFloat)` | `String`, `CGFloat` | the cell font | A registered family at a fixed size, for the header row alone |
| `.headerTextColor(_:)` | `Color \| semantic` | `.primary` | Header row text color |
| `.headerBackground(_:)` | `Color \| semantic` | `tertiarySystemFill` | Header row fill |
| `.rowOddBackground(_:)` / `.rowEvenBackground(_:)` | `Color \| semantic` | `quaternarySystemFill` / unset | Zebra striping for body rows |
| `.borderColor(_:)` | `Color \| semantic` | `separator` | Color of the grid and outer border |
| `.borderWidth(_:)` | `CGFloat` | `1` | Thickness of both |
| `.cornerRadius(_:)` | `CGFloat` | `6` | Rounds the outer border. `.borderRadius(_:)` is an alias |
| `.cellPaddingHorizontal(_:)` / `.cellPaddingVertical(_:)` | `CGFloat` | `12` / `8` | Inset inside every cell |
| `.align(_ value: TableAlignment)` | `TableAlignment` | unset | Default column alignment where the Markdown separator row does not specify one. `.leading`, `.center`, `.trailing` |

```swift
MarkdownTheme {
  Table()
    .headerTextColor(.primary)
    .headerBackground(Color(.systemGray5))
    .rowOddBackground(Color(.systemGray6))
    .borderColor(Color(.separator))
    .borderWidth(1)
    .cornerRadius(8)
    .cellPaddingHorizontal(14)
    .cellPaddingVertical(10)
    .align(.leading)
}
```

Line height defaults to `20`, cell color to `.primary`, and margin bottom to `16`.

:::note
Use `.align(_:)` for column alignment - it takes the package's own `TableAlignment`, not SwiftUI's `HorizontalAlignment`. `Table()` also accepts the shared `.textAlignment(_:)` because it shares the base element protocol, but nothing reads it: a table's alignment comes from `.align(_:)` and from the Markdown separator row.
:::

### `CodeBlock()` {#codeblock}

Fenced code blocks. This element does **not** take the shared set - these are all its modifiers:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.font(_:)` | `Font` | `.system(.body, design: .monospaced)` | Text style for the code |
| `.fontFamily(_ name:size:)` | `String`, `CGFloat` | unset | A registered family at a fixed size |
| `.fontSize(_ size:weight:)` | `CGFloat`, `Font.Weight` | unset | A fixed system size |
| `.foregroundStyle(_:)` | `Color \| semantic` | `.primary` | Code color |
| `.background(_:)` | `Color \| semantic` | `.quaternary` | Fill behind the block |
| `.padding(_:)` | `CGFloat` | `12` | Space between the fill's edge and the code |
| `.cornerRadius(_:)` | `CGFloat` | `8` | Rounds the fill. `.borderRadius(_:)` is an alias |
| `.borderColor(_:)` | `Color \| semantic` | unset | Outline around the fill |
| `.borderWidth(_:)` | `CGFloat` | unset | Thickness of that outline |
| `.lineHeight(_:)` | `CGFloat` | unset | Line height in points |
| `.marginTop(_:)` / `.marginBottom(_:)` | `CGFloat` | unset / `16` | Space above and below |

```swift
MarkdownTheme {
  CodeBlock()
    .fontFamily("JetBrainsMono-Regular", size: 13)
    .background(Color(.secondarySystemBackground))
    .borderColor(Color(.separator))
    .borderWidth(1)
    .cornerRadius(10)
    .padding(14)
}
```

A block keeps the monospaced design unless you replace it explicitly: `.font(.body)` re-sizes the monospaced face, while `.font(.system(.body, design: .serif))` or `.fontFamily(_:size:)` gives you the face you named.

The fence's language label is parsed and available to the renderer, but this package ships no syntax highlighting - see [Code-block syntax highlighting](/rich-text-formatting/code-highlighting).

### `Code()` {#code}

Inline `` `code` ``. Takes the [shared modifiers](#shared-modifiers) plus `.background(_:)`:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.fontDesign(_:)` | `Font.Design` | `.monospaced` | Kept at the size of the surrounding text |
| `.foregroundStyle(_:)` | `Color \| semantic` | `.secondary` | Text color |
| `.background(_:)` | `Color \| semantic` | `.quaternary` | The chip behind the code |

```swift
MarkdownTheme {
  Code()
    .foregroundStyle(.pink)
    .background(Color.pink.opacity(0.12))
}
```

Leaving the font unset is what keeps inline code the size of the line it sits in - inline code in a heading is heading-sized. Passing `.fontSize(_:weight:)` or `.fontFamily(_:size:)` pins it to that size everywhere.

### `Link()` {#link}

Links and autolinks. Takes the [shared modifiers](#shared-modifiers) plus:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.underline(_ enabled: Bool = true)` | `Bool` | `true` | Whether the link is underlined |
| `.foregroundStyle(_:)` | `Color \| semantic` | `.tint` | Link color; everything else is inherited from the surrounding block |

```swift
MarkdownTheme {
  Link()
    .foregroundStyle(.blue)
    .underline(false)
}
```

A tapped link runs [`.onLinkPress`](/ios/api-reference/enriched-markdown-text#onlinkpress) when you install it, and otherwise opens with the system.

### `Strong()`, `Emphasis()`, `Strikethrough()` {#strong-emphasis-strikethrough}

Bold, italic, and struck-through text. Each takes the [shared modifiers](#shared-modifiers), and each sets **nothing** by default: the weight, slant, or line comes from the renderer and everything else is inherited.

```swift
MarkdownTheme {
  Strong().foregroundStyle(.primary)
  Emphasis().foregroundStyle(.secondary)
  Strikethrough().foregroundStyle(.tertiary)
}
```

Setting a color on one pins it document-wide, including inside headings and quotes.

### `Underline()` {#underline}

Underlined text, from `_text_` and `__text__` with `Md4cFlags(underline: true)`. Takes the [shared modifiers](#shared-modifiers); nothing set by default.

```swift
EnrichedMarkdownText(content, flags: Md4cFlags(underline: true))
  .markdownTheme {
    Underline().foregroundStyle(.tint)
  }
```

:::note
The option **replaces** the usual meaning of those markers. With it on, `_text_` is underlined rather than italic - use `*text*` and `**text**` for italic and bold.
:::

### `Superscript()` / `Subscript()` {#superscript--subscript}

Raised and lowered text, from `^text^` and `~text~` with the matching option. Both scale relative to the text around them, so these are the only two modifiers - font and color follow the surrounding text:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.fontScale(_:)` | `CGFloat` | `0.75` | Size as a fraction of the surrounding text size |
| `.baselineOffsetScale(_:)` | `CGFloat` | `0.35` superscript, `0.20` subscript | Baseline shift as a fraction of the surrounding text size - upward for `Superscript`, downward for `Subscript`. Pass a positive number for both |

```swift
MarkdownTheme {
  Superscript()
    .fontScale(0.7)
    .baselineOffsetScale(0.4)

  Subscript()
    .fontScale(0.7)
    .baselineOffsetScale(0.25)
}
```

Because the values are fractions, superscript inside an `h1` is larger than superscript in a paragraph, automatically.

### `Highlight()` {#highlight}

`==text==` with `Md4cFlags(highlight: true)`. Takes the [shared modifiers](#shared-modifiers) plus:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.background(_:)` | `Color \| semantic` | `#FEF08A` | The highlight behind the text |

```swift
MarkdownTheme {
  Highlight()
    .background(Color.yellow.opacity(0.3))
    .foregroundStyle(.primary)     // set both, so dark mode stays readable
}
```

:::caution
The default highlight background is a **fixed** light yellow and does not adapt to dark mode, where the surrounding text color may leave it unreadable. If you enable the option, set both a background and a foreground for the appearance you support.
:::

### `Spoiler()` {#spoiler}

The overlay concealing `||spoiler||` text until it is tapped. Spoilers are always parsed; the overlay's shape is chosen with [`.markdownSpoilerOverlay`](/ios/api-reference/enriched-markdown-text#markdownspoileroverlay). Once revealed, the text keeps the surrounding font and color, so this element styles the cover only:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.color(_:)` | `Color \| semantic` | `.secondary` | The particles, or the fill of the solid box |
| `.background(_:)` | `Color \| semantic` | `systemBackground` | Backdrop painted under the particles, hiding the text through the gaps. The solid overlay ignores it |
| `.particleDensity(_:)` | `CGFloat` | `8` | How thickly the particle overlay spawns dots. A **relative** figure rather than a count: the field scales linearly from the default, so `16` is twice as dense as `8` |
| `.particleSpeed(_:)` | `CGFloat` | `20` | How fast those dots drift, on the same relative scale - `40` moves twice as fast as the default. The dots themselves travel a few points per second, outwards in every direction |
| `.solidBorderRadius(_:)` | `CGFloat` | `4` | Corner radius of the solid overlay. The particle overlay ignores it |

```swift
EnrichedMarkdownText(content)
  .markdownSpoilerOverlay(.particles)
  .markdownTheme {
    Spoiler()
      .color(.secondary)
      .particleDensity(16)   // twice the default
      .particleSpeed(30)
  }
```

The last three apply only to the overlay they name, and **which** overlay is drawn is not part of the theme - pick it with [`.markdownSpoilerOverlay`](/ios/api-reference/enriched-markdown-text#markdownspoileroverlay), then style it here.

### `BlockImage()` {#blockimage}

An image alone in its paragraph. Four modifiers, no font or color:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.height(_:)` | `CGFloat` | `200` | Rendered height in points; the image spans the container width |
| `.borderRadius(_:)` | `CGFloat` | `8` | Rounds the image |
| `.marginTop(_:)` | `CGFloat` | unset | Overrides the paragraph margin above an image-only paragraph |
| `.marginBottom(_:)` | `CGFloat` | `16` | Overrides the paragraph margin below it |

```swift
MarkdownTheme {
  BlockImage()
    .height(240)
    .borderRadius(12)
    .marginBottom(24)
}
```

Width, aspect ratio, and content mode are not configurable yet - see the [roadmap](/misc/roadmap#ios).

### `InlineImage()` {#inlineimage}

An image sharing a line with text, drawn like an oversized glyph. One modifier:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.size(_:)` | `CGFloat` | `20` | Side length in points |

```swift
MarkdownTheme {
  InlineImage().size(24)
}
```

Which of the two an image becomes depends on what else is in its paragraph - see [Images: block vs. inline](/ios/api-reference/element-structure#images-block-vs-inline).

### `ThematicBreak()` {#thematicbreak}

The rule drawn for `---`. It has no text of its own, so these are all its modifiers:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.color(_:)` | `Color \| semantic` | `.secondary` | Color of the rule |
| `.foregroundStyle(_ semantic:)` | semantic | `.secondary` | The same thing, semantic colors only - `.color(_:)` is the one that also takes a `Color` |
| `.height(_:)` | `CGFloat` | `1` | Thickness of the rule |
| `.marginTop(_:)` / `.marginBottom(_:)` | `CGFloat` | `24` / `24` | Space above and below |

```swift
MarkdownTheme {
  ThematicBreak()
    .color(Color(.separator))
    .height(2)
    .marginTop(32)
    .marginBottom(32)
}
```

## See also

- [`MarkdownTheme`](/ios/api-reference/markdown-theme) - building, providing, and layering themes.
- [Element structure](/ios/api-reference/element-structure) - what each Markdown construct renders as.
- [Custom fonts](/ios/guides/custom-fonts) - `.font(custom:size:)`, bold faces, and Dynamic Type.
