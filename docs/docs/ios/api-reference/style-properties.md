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
| [`Underline()`](#underline) | Underlined text (needs `MarkdownParsingOptions(underline: true)`) |
| [`Superscript()` / `Subscript()`](#superscript--subscript) | Raised and lowered text (needs the matching option) |
| [`Highlight()`](#highlight) | Highlighted text (needs `MarkdownParsingOptions(highlight: true)`) |
| [`Spoiler()`](#spoiler) | The overlay concealing `\|\|spoiler\|\|` text |
| [`BlockImage()`](#blockimage) | Images alone in a paragraph |
| [`InlineImage()`](#inlineimage) | Images sharing a line with text |
| [`ThematicBreak()`](#thematicbreak) | Horizontal rules |

`MathBlock()` and `InlineMath()` come with the `EnrichedMarkdownLaTeX` product - see [LaTeX math](/ios/guides/latex-math#styling).

## Shared modifiers {#shared-modifiers}

Most elements accept the same base set. Where an element does **not**, its section below says so.

| Modifier | Effect |
| --- | --- |
| `.font(_ font: Font)` | A SwiftUI text style, in any spelling (`.body`, `.system(.title)`, `.system(.title, design: .serif, weight: .bold)`). Scales with Dynamic Type |
| `.font(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design? = nil)` | A **fixed** system size |
| `.font(custom name: String, size: CGFloat)` | A registered font family at a **fixed** size |
| `.fontWeight(_ weight: Font.Weight)` | Weight only, over whatever font a lower layer set |
| `.bold()` | Shorthand for `.fontWeight(.bold)` |
| `.italic(_ isActive: Bool = true)` | The family's italic face, or a synthesized slant when it has none |
| `.fontDesign(_ design: Font.Design)` | `.default`, `.serif`, `.rounded`, `.monospaced` - system fonts only |
| `.foregroundStyle(_ color: Color)` | Text color |
| `.foregroundStyle(_ semantic:)` | `.primary`, `.secondary`, `.tertiary`, `.quaternary`, `.tint` - adapt to light and dark |
| `.marginTop(_ value: CGFloat)` | Space above the block |
| `.marginBottom(_ value: CGFloat)` | Space below the block |
| `.lineHeight(_ value: CGFloat)` | Line height in points |
| `.multilineTextAlignment(_ alignment: TextAlignment)` | `.leading`, `.center`, `.trailing` |

`.fontWeight`, `.bold()`, `.italic()`, and `.fontDesign` **layer** over the font a lower theme layer set, so `Heading(1).bold()` on its own bolds the default heading font rather than replacing it.

Background modifiers - `.background(_:)` and its alias `.backgroundStyle(_:)` - are available on `Code`, `CodeBlock`, `Blockquote`, `Admonition`, `Highlight`, and `Spoiler` only; a paragraph or heading has no fill.

:::caution
`.font(size:)` and `.font(custom:size:)` take a point size, which **opts the element out of Dynamic Type**. Use `.font(.body)` and its siblings unless you have a reason not to; see [Custom fonts](/ios/guides/custom-fonts).
:::

:::note
`.font(_:)` reads back a SwiftUI **text style** only. A point-sized or otherwise modified `Font` - `.system(size: 17)`, `.custom(_:size:)`, `.weight()`, `.italic()` - cannot be inspected through public API, so passing one logs a runtime warning and renders as `.body`. Use `.font(size:weight:design:)` and `.font(custom:size:)` for those.
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

## Dark mode

`MarkdownTheme.default` is built from semantic colors and adapts on its own. A theme you write adapts only as far as the colors you give it do - see [Light, dark, and Dynamic Type](/ios/api-reference/markdown-theme#appearance) for which values follow the appearance and which are frozen.

## Property reference

### `Paragraph()` {#paragraph}

Body text. Takes the [shared modifiers](#shared-modifiers); no background.

| Property | Default |
| --- | --- |
| Font | `.body` |
| Color | `.primary` |
| Line height | `26` |
| Margin bottom | `16` |
| Margin top, alignment | unset |

### `Heading(_ level: Int)` {#heading}

One heading level, 1 through 6. The level is clamped into that range, so `Heading(9)` styles `h6`. Takes the [shared modifiers](#shared-modifiers); no background.

| Level | Font | Color | Margin bottom |
| --- | --- | --- | --- |
| `Heading(1)` | `.largeTitle`, bold | `.primary` | `8` |
| `Heading(2)` | `.title`, bold | `.primary` | `8` |
| `Heading(3)` | `.title2`, bold | `.primary` | `8` |
| `Heading(4)` | `.title3`, bold | `.primary` | `8` |
| `Heading(5)` | `.headline` | `.primary` | `8` |
| `Heading(6)` | `.subheadline` | `.secondary` | `8` |

### `Blockquote()` {#blockquote}

Block quotes, and the geometry every admonition inherits. Takes the [shared modifiers](#shared-modifiers) plus:

#### `.border(_ color:, width:)`

The accent bar down the side of the quote - its color and thickness together, as SwiftUI's own `border(_:width:)`. Leave `width` out to recolor a bar a lower layer sized. An [`Admonition()`](#admonition) tint overrides the color for that alert type.

<PropInfo type="Color | semantic, CGFloat?" default=".tint, 3" />

#### `.gapWidth(_:)`

Space between the bar and the quoted text.

<PropInfo type="CGFloat" default="16" />

#### `.background(_:)`

Fill behind the quote.

<PropInfo type="Color | semantic" default="unset" />

Font defaults to `.body`, color to `.secondary`, and margin bottom to `16`. Nested quotes each draw their own bar, so depth stays visible.

### `Admonition(_ type: AdmonitionType)` {#admonition}

Colors for **one** GitHub alert type. Geometry, font, and spacing come from [`Blockquote()`](#blockquote) - an admonition only recolors it, so these two modifiers are the whole surface:

#### `.foregroundStyle(_:)`

Tints the accent bar, the icon, and the title together.

<PropInfo type="Color | semantic" default="per type, see below" />

#### `.background(_:)`

Fill behind the callout.

<PropInfo type="Color | semantic" default="unset - no fill" />

```swift
MarkdownTheme {
  Admonition(.warning)
    .foregroundStyle(.orange)
    .background(Color.orange.opacity(0.12))
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

A type you never style falls back to the blockquote's border color. Admonitions need `MarkdownParsingOptions(admonitions: true)`; see [Parser extensions](/ios/guides/parser-extensions#admonitions).

### `List()` {#list}

Ordered and unordered lists, and their markers. Takes the [shared modifiers](#shared-modifiers) - which style the item **text** - plus:

#### `.bulletColor(_:)`

The dot drawn for an unordered item.

<PropInfo type="Color | semantic" default=".secondary" />

#### `.bulletSize(_:)`

Diameter of that dot, in points.

<PropInfo type="CGFloat" default="6" />

#### `.markerColor(_:)`

The `1.` `2.` `3.` of an ordered item.

<PropInfo type="Color | semantic" default=".secondary" />

#### `.markerMinWidth(_:)`

Minimum width reserved for the marker column, so numbers past `9.` do not shift the text. `0` sizes the column to each marker.

<PropInfo type="CGFloat" default="0" />

#### `.gapWidth(_:)`

Space between the marker and the item text. Clamped to a minimum of `4`.

<PropInfo type="CGFloat" default="12" />

#### `.marginLeading(_:)`

Indent added per nesting level, on the paragraph's leading side.

<PropInfo type="CGFloat" default="24" />

Font defaults to `.body`, color to `.primary`, and margin bottom to `16`.

### `TaskList()` {#tasklist}

The checkboxes of `- [ ]` / `- [x]` items, and what a checked item's text looks like. Item text itself is styled by [`List()`](#list), so this element takes **only** these modifiers - no font, no margins.

#### `.checkboxSize(_:)`

Side length of the box, in points.

<PropInfo type="CGFloat" default="14" />

#### `.checkboxCornerRadius(_:)`

Corner radius of the box.

<PropInfo type="CGFloat" default="3" />

#### `.checkedColor(_:)`

Fill of a checked box.

<PropInfo type="Color | semantic" default=".tint" />

#### `.borderColor(_:)`

Outline of an unchecked box.

<PropInfo type="Color | semantic" default=".secondary" />

#### `.checkmarkColor(_:)`

The tick inside a checked box.

<PropInfo type="Color | semantic" default=".white" />

#### `.checkedTextColor(_:)`

Recolors the text of a checked item - the usual "done, dimmed" treatment. Unset leaves it the same as an unchecked item.

<PropInfo type="Color | semantic" default="unset" />

#### `.checkedStrikethrough(_ enabled: Bool = true)`

Strikes through the text of a checked item.

<PropInfo type="Bool" default="false" />

Both of the last two apply the moment the reader toggles a box, not only on the first render.

### `Table()` {#table}

GFM tables. Takes the [shared modifiers](#shared-modifiers) for the **cell** text, plus:

#### `.headerFont(_ font: Font)` / `.headerFont(custom name: String, size: CGFloat)`

The header row's font alone - a SwiftUI text style, or a registered family at a fixed size.

<PropInfo type="Font | String, CGFloat" default="the cell font" />

#### `.headerForegroundStyle(_:)`

<PropInfo type="Color | semantic" default=".primary" />

#### `.headerBackground(_:)`

<PropInfo type="Color | semantic" default="tertiarySystemFill" />

#### `.rowOddBackground(_:)` / `.rowEvenBackground(_:)`

Zebra striping for body rows.

<PropInfo type="Color | semantic" default="quaternarySystemFill / unset" />

#### `.border(_ color:, width:)`

The table's grid and outer border - color and width together. Leave `width` out to recolor a border a lower layer sized.

<PropInfo type="Color | semantic, CGFloat?" default="separator, 1" />

#### `.cornerRadius(_:)`

Rounds the table's outer border.

<PropInfo type="CGFloat" default="6" />

#### `.cellPadding(horizontal:vertical:)`

Inset of every cell. Both arguments are optional; a side you leave out keeps what a lower theme layer set.

<PropInfo type="CGFloat?, CGFloat?" default="12 / 8" />

#### `.alignment(_ value: HorizontalAlignment)`

Default horizontal alignment of cell content for columns whose Markdown separator row does not specify one. Only `.leading`, `.center`, and `.trailing` apply; any other `HorizontalAlignment` logs a warning and leaves the inherited value.

<PropInfo type="HorizontalAlignment" default="unset" />

Line height defaults to `20`, cell color to `.primary`, and margin bottom to `16`.

:::note
Use `.alignment(_:)` for column alignment. `Table()` accepts the shared `.multilineTextAlignment(_:)` because it shares the base element protocol, but nothing reads it - a table's alignment comes from `.alignment` and from the Markdown separator row.
:::

### `CodeBlock()` {#codeblock}

Fenced code blocks. Takes the [shared modifiers](#shared-modifiers) - alignment among them, though a code block always lays out left-to-right and ignores it - plus:

#### `.background(_:)`

Fill behind the block.

<PropInfo type="Color | semantic" default=".quaternary" />

#### `.padding(_:)`

Space between the fill's edge and the code.

<PropInfo type="CGFloat" default="12" />

#### `.cornerRadius(_:)`

Rounds the fill.

<PropInfo type="CGFloat" default="8" />

#### `.border(_ color:, width:)`

An outline around the fill - color and width together.

<PropInfo type="Color | semantic, CGFloat?" default="unset" />

Font defaults to `.system(.body, design: .monospaced)`, color to `.primary`, and margin bottom to `16`. A block keeps the monospaced design unless you replace it explicitly: `.font(.body)` re-sizes the monospaced face, while `.font(.system(.body, design: .serif))` or `.font(custom:size:)` gives you the face you named.

The fence's language label is parsed and available to the renderer, but this package ships no syntax highlighting - see [Code-block syntax highlighting](/rich-text-formatting/code-highlighting).

### `Code()` {#code}

Inline `` `code` ``. Takes the [shared modifiers](#shared-modifiers) plus `.background(_:)`.

| Property | Default |
| --- | --- |
| Font | monospaced, **at the size of the surrounding text** |
| Color | `.secondary` |
| Background | `.quaternary` |

Leaving the font unset is what keeps inline code the size of the line it sits in - inline code in a heading is heading-sized. Passing `.font(size:)` or `.font(custom:size:)` pins it to that size everywhere.

### `Link()` {#link}

Links and autolinks. Takes the [shared modifiers](#shared-modifiers) plus:

#### `.underline(_ enabled: Bool = true)`

<PropInfo type="Bool" default="true" />

Color defaults to `.tint`; everything else is inherited from the surrounding block. A tapped link goes to SwiftUI's [`openURL`](/ios/api-reference/enriched-markdown-text#openurl) action, which opens it with the system unless you install your own.

### `Strong()`, `Emphasis()`, `Strikethrough()` {#strong-emphasis-strikethrough}

Bold, italic, and struck-through text. Each takes the [shared modifiers](#shared-modifiers), and each sets **nothing** by default: the weight, slant, or line comes from the renderer and everything else is inherited.

Setting a color on one pins it document-wide, including inside headings and quotes.

### `Underline()` {#underline}

Underlined text, from `_text_` and `__text__` with `MarkdownParsingOptions(underline: true)`. Takes the [shared modifiers](#shared-modifiers); nothing set by default.

:::note
The option **replaces** the usual meaning of those markers. With it on, `_text_` is underlined rather than italic - use `*text*` and `**text**` for italic and bold.
:::

### `Superscript()` / `Subscript()` {#superscript--subscript}

Raised and lowered text, from `^text^` and `~text~` with the matching option. Both scale relative to the text around them, so these are the only two modifiers - font and color follow the surrounding text:

#### `.fontScale(_:)`

Size as a fraction of the surrounding text size.

<PropInfo type="CGFloat" default="0.75" />

#### `.baselineOffsetScale(_:)`

Baseline shift as a fraction of the surrounding text size - upward for `Superscript`, downward for `Subscript`. Pass a positive number for both.

<PropInfo type="CGFloat" default="0.35 superscript, 0.20 subscript" />

Because the values are fractions, superscript inside an `h1` is larger than superscript in a paragraph, automatically.

### `Highlight()` {#highlight}

`==text==` with `MarkdownParsingOptions(highlight: true)`. Takes the [shared modifiers](#shared-modifiers) plus `.background(_:)`.

<PropInfo type="Color | semantic" default="#FEF08A" />

:::caution
The default highlight background is a **fixed** light yellow and does not adapt to dark mode, where the surrounding text color may leave it unreadable. If you enable the option, set both a background and a foreground for the appearance you support.
:::

### `Spoiler()` {#spoiler}

The overlay concealing `||spoiler||` text until it is tapped. Spoilers are always parsed; the overlay's shape is chosen with [`.markdownSpoilerOverlay`](/ios/api-reference/enriched-markdown-text#markdownspoileroverlay). Once revealed, the text keeps the surrounding font and color, so this element styles the cover only:

#### `.foregroundStyle(_:)`

The particles, or the fill of the solid box.

<PropInfo type="Color | semantic" default=".secondary" />

#### `.background(_:)`

Backdrop painted under the particles, hiding the text through the gaps.

<PropInfo type="Color | semantic" default="systemBackground" />

Those two are the whole element. The overlay's **geometry and motion** - particle density and speed, the solid box's corner radius - are tuning of the overlay rather than of the theme, so they are passed where the overlay is chosen:

```swift
EnrichedMarkdownText(content)
  .markdownSpoilerOverlay(.particles(density: 12, speed: 30))  // defaults: 8, 20

EnrichedMarkdownText(content)
  .markdownSpoilerOverlay(.solid(cornerRadius: 6))             // default: 4
```

### `BlockImage()` {#blockimage}

An image alone in its paragraph. Four modifiers, no font or color:

#### `.height(_:)`

Rendered height in points; the image spans the container width.

<PropInfo type="CGFloat" default="200" />

#### `.cornerRadius(_:)`

<PropInfo type="CGFloat" default="8" />

#### `.marginTop(_:)` / `.marginBottom(_:)`

Override the paragraph margins for image-only paragraphs.

<PropInfo type="CGFloat" default="unset / 16" />

Width, aspect ratio, and content mode are not configurable yet - see the [roadmap](/misc/roadmap#ios).

### `InlineImage()` {#inlineimage}

An image sharing a line with text, drawn like an oversized glyph. One modifier:

#### `.size(_:)`

Side length in points.

<PropInfo type="CGFloat" default="20" />

Which of the two an image becomes depends on what else is in its paragraph - see [Images: block vs. inline](/ios/api-reference/element-structure#images-block-vs-inline).

### `ThematicBreak()` {#thematicbreak}

The rule drawn for `---`. It has no text of its own, so these are all its modifiers:

#### `.foregroundStyle(_:)`

<PropInfo type="Color | semantic" default=".secondary" />

#### `.height(_:)`

Thickness of the rule.

<PropInfo type="CGFloat" default="1" />

#### `.marginTop(_:)` / `.marginBottom(_:)`

<PropInfo type="CGFloat" default="24 / 24" />

## See also

- [`MarkdownTheme`](/ios/api-reference/markdown-theme) - building, providing, and layering themes.
- [Element structure](/ios/api-reference/element-structure) - what each Markdown construct renders as.
- [Custom fonts](/ios/guides/custom-fonts) - `.font(custom:size:)`, bold faces, and Dynamic Type.
