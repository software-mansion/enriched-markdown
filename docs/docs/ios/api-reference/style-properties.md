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
| [`SyntaxToken(_:)`](#syntaxtoken) | One token type's color in a highlighted code block (needs the `EnrichedMarkdownSyntaxHighlighting` product) |

`MathBlock()` and `InlineMath()` come with the `EnrichedMarkdownLaTeX` product - see [LaTeX math](/ios/guides/latex-math#styling).

## Shared modifiers {#shared-modifiers}

The elements that carry text - `Paragraph`, `Heading`, `Blockquote`, `List`, `Table`, `CodeBlock`, `Code`, `Link`, `Strong`, `Emphasis`, `Strikethrough`, `Underline`, `Highlight` - accept this base set. Every one of them compiles, but not every element reads every modifier; see [which modifiers each element honors](#honored-modifiers) below the table.

| Modifier | Effect |
| --- | --- |
| `.font(_ font: Font)` | A SwiftUI text style, in any spelling (`.body`, `.system(.title)`, `.system(.title, design: .serif, weight: .bold)`). Scales with Dynamic Type |
| `.font(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design? = nil)` | A **fixed** system size |
| `.font(custom name: String, size: CGFloat)` | A registered font family at a **fixed** size |
| `.bold()` | Bold weight, over whatever font a lower layer set. Shorthand for `.fontWeight(.bold)` |
| `.fontWeight(_ weight: Font.Weight)` | Any weight, over whatever font a lower layer set. On a custom family, only `.semibold` and heavier do anything - they switch to the family's bold face |
| `.italic(_ isActive: Bool = true)` | The family's italic face, or a synthesized slant when it has none. `.italic(false)` removes an italic a lower layer set |
| `.fontDesign(_ design: Font.Design)` | `.default`, `.serif`, `.rounded`, `.monospaced` - system fonts only |
| `.foregroundStyle(_ color: Color)` | Text color |
| `.foregroundStyle(_ semantic:)` | `.primary`, `.secondary`, `.tertiary`, `.quaternary`, `.tint` - adapt to light and dark |
| `.marginTop(_ value: CGFloat)` | Space above the block |
| `.marginBottom(_ value: CGFloat)` | Space below the block |
| `.lineHeight(_ value: CGFloat)` | Line height in points |
| `.multilineTextAlignment(_ alignment: TextAlignment)` | `.leading`, `.center`, `.trailing` |

```swift
MarkdownTheme {
  Paragraph()
    .font(.body)
    .foregroundStyle(.primary)
    .lineHeight(26)
    .marginBottom(16)

  Heading(2)
    .font(custom: "Inter-SemiBold", size: 24)   // fixed size, no Dynamic Type
    .multilineTextAlignment(.leading)
}
```

`.bold()`, `.fontWeight(_:)`, `.italic(_:)`, and `.fontDesign(_:)` **layer** over the font a lower theme layer set, so `Heading(1).bold()` on its own bolds the default heading font rather than replacing it.

### Which modifiers each element honors {#honored-modifiers}

The base set is shared through one protocol, so it compiles on every text element - but a renderer reads only what that element can use:

| Element | Font modifiers | Color | Margins, line height | `.multilineTextAlignment` |
| --- | --- | --- | --- | --- |
| `Paragraph`, `Heading`, `CodeBlock` | Yes | Yes | Yes | Yes |
| `Blockquote`, `List` | Yes | Yes | Yes | **Ignored** |
| `Table` | Yes - see [`Table()`](#table) for the size | Yes | Yes | **Ignored** - use `.alignment(_:)` |
| `Code` | Yes - any font pins inline code, see [`Code()`](#code) | Yes | **Ignored** | **Ignored** |
| `Link`, `Strong`, `Emphasis`, `Strikethrough`, `Underline`, `Highlight` | **Ignored** | Yes | **Ignored** | **Ignored** |

:::caution
On `Link`, `Strong`, `Emphasis`, `Strikethrough`, `Underline`, and `Highlight`, the font modifiers - `.font(_:)`, `.font(size:weight:design:)`, `.font(custom:size:)`, `.bold()`, `.fontWeight(_:)`, `.italic(_:)`, `.fontDesign(_:)` - compile and do nothing. These elements always render in the font of the block they sit in, bolded or slanted by the renderer where the element calls for it. Change the block's font instead.
:::

The elements that are not text blocks take their own modifiers instead, listed in their sections below: [`TaskList()`](#tasklist), [`Admonition()`](#admonition), [`Spoiler()`](#spoiler), [`BlockImage()`](#blockimage), [`InlineImage()`](#inlineimage), [`ThematicBreak()`](#thematicbreak), [`Superscript()` / `Subscript()`](#superscript--subscript), and [`SyntaxToken(_:)`](#syntaxtoken).

Background modifiers - `.background(_:)` and its alias `.backgroundStyle(_:)` - are available on `Code`, `CodeBlock`, `Blockquote`, `Admonition`, `Highlight`, and `Spoiler` only; a paragraph or heading has no fill.

:::caution
`.font(size:weight:design:)` and `.font(custom:size:)` take a point size, which **opts the element out of Dynamic Type**. Use `.font(.body)` and its siblings unless you have a reason not to; see [Custom fonts](/ios/guides/custom-fonts).
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

## Dark mode and Dynamic Type {#adaptive-values}

`MarkdownTheme.default` is built from semantic colors and system text styles, so it adapts to both the appearance and the text size on its own. A theme you write adapts only as far as the values you give it do:

| You write | What adapts |
| --- | --- |
| `.font(.body)`, `.font(.largeTitle)`, any SwiftUI text style | Size follows **Dynamic Type** |
| `.font(size: 17)`, `.font(custom: "Inter", size: 17)` | Nothing - a fixed point size |
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
| `.multilineTextAlignment(_:)` | `TextAlignment` | unset | `.leading`, `.center`, or `.trailing` |

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
| `.border(_:width:)` | `Color \| semantic`, `CGFloat?` | `.tint`, `3` | Color of the accent bar down the side, and optionally its thickness. An [`Admonition()`](#admonition) tint overrides the color for that alert type |
| `.border(width:)` | `CGFloat` | `3` | Thickness alone, keeping the color a lower layer set |
| `.gapWidth(_:)` | `CGFloat` | `16` | Space between the bar and the quoted text |
| `.background(_:)` | `Color \| semantic` | `#FAFAFC` | Fill behind the quote. Left unset, the renderer draws a **fixed** near-white `#FAFAFC` that does not adapt to dark mode |

```swift
MarkdownTheme {
  Blockquote()
    .border(.secondary, width: 4)
    .gapWidth(12)
    .background(Color(.secondarySystemBackground))
}
```

Font defaults to `.body`, color to `.secondary`, and margin bottom to `16`. Nested quotes each draw their own bar, so depth stays visible.

:::caution
The default quote fill is a fixed light color, so in dark mode a quote sits on a near-white box. If your app supports dark mode, set `.background(_:)` to an adaptive color such as `Color(.secondarySystemBackground)` - or `.clear` for no fill.
:::

### `Admonition(_ type: AdmonitionType)` {#admonition}

Colors for **one** GitHub alert type. Geometry, font, and spacing come from [`Blockquote()`](#blockquote) - an admonition only recolors it, so these two modifiers are the whole surface:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.foregroundStyle(_:)` | `Color \| semantic` | per type, see below | Tints the accent bar, the icon, and the title together |
| `.background(_:)` | `Color \| semantic` | unset - no fill | Fill behind the callout. An admonition does **not** inherit the `Blockquote()` background: unset means no fill |

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

A type you never style falls back to the blockquote's border color. Admonitions need `MarkdownParsingOptions(admonitions: true)`; see [Parser extensions](/ios/guides/parser-extensions#admonitions).

### `List()` {#list}

Ordered and unordered lists, and their markers. Takes the [shared modifiers](#shared-modifiers) - which style the item **text** - plus:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.bulletColor(_:)` | `Color \| semantic` | `.secondary` | The dot drawn for an unordered item |
| `.bulletSize(_:)` | `CGFloat` | `6` | Diameter of that dot, in points |
| `.markerColor(_:)` | `Color \| semantic` | `.secondary` | The `1.` `2.` `3.` of an ordered item |
| `.markerMinWidth(_:)` | `CGFloat` | `0` | Minimum width reserved for the marker column. An ordered list's column also grows to fit its widest number, so its markers are never clipped |
| `.gapWidth(_:)` | `CGFloat` | `12` | Space between the marker and the item text. Clamped to a minimum of `4` |
| `.marginLeading(_:)` | `CGFloat` | `24` | Indent added per nesting level |

```swift
MarkdownTheme {
  List()
    .bulletColor(.tint)
    .bulletSize(8)
    .markerColor(.tint)
    .markerMinWidth(24)   // keeps text aligned past "9."
    .gapWidth(10)
    .marginLeading(20)
}
```

Font defaults to `.body`, color to `.primary`, and margin bottom to `16`.

### `TaskList()` {#tasklist}

The checkboxes of `- [ ]` / `- [x]` items, and what a checked item's text looks like. Item text itself is styled by [`List()`](#list), so this element takes **only** these modifiers - no font, no margins:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.checkboxSize(_:)` | `CGFloat` | `14` | Side length of the box, in points |
| `.checkboxCornerRadius(_:)` | `CGFloat` | `3` | Corner radius of the box |
| `.checkedColor(_:)` | `Color \| semantic` | `.tint` | Fill of a checked box |
| `.borderColor(_:)` | `Color \| semantic` | `.secondary` | Outline of an unchecked box |
| `.checkmarkColor(_:)` | `Color \| semantic` | `.white` | The tick inside a checked box |
| `.checkedTextColor(_:)` | `Color \| semantic` | unset | Recolors the text of a checked item - the usual "done, dimmed" treatment. Unset leaves it the same as an unchecked item |
| `.checkedStrikethrough(_ enabled: Bool = true)` | `Bool` | `false` | Strikes through the text of a checked item |

```swift
MarkdownTheme {
  TaskList()
    .checkboxSize(18)
    .checkboxCornerRadius(9)      // a circle, at half the size
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
| `.headerFont(custom name: String, size: CGFloat)` | `String`, `CGFloat` | the cell font | A registered family at a fixed size, for the header row alone |
| `.headerFont(_:)` | `Font` | the cell font | A SwiftUI text style for the header row alone |
| `.headerForegroundStyle(_:)` | `Color \| semantic` | `.primary` | Header row text color |
| `.headerBackground(_:)` | `Color \| semantic` | `tertiarySystemFill` | Header row fill |
| `.rowOddBackground(_:)` / `.rowEvenBackground(_:)` | `Color \| semantic` | `quaternarySystemFill` / unset | Zebra striping for body rows |
| `.border(_:width:)` | `Color \| semantic`, `CGFloat?` | `separator`, `1` | Color of the grid and outer border, and optionally its thickness |
| `.border(width:)` | `CGFloat` | `1` | Thickness alone, keeping the color a lower layer set |
| `.cornerRadius(_:)` | `CGFloat` | `6` | Rounds the outer border |
| `.cellPadding(horizontal:vertical:)` | `CGFloat?`, `CGFloat?` | `12` / `8` | Inset inside every cell; a side you omit keeps what a lower layer set |
| `.alignment(_ value: HorizontalAlignment)` | `HorizontalAlignment` | `.leading` | Where a table **narrower than the text** sits. `.leading`, `.center`, `.trailing` |

```swift
MarkdownTheme {
  Table()
    .headerForegroundStyle(.primary)
    .headerBackground(Color(.systemGray5))
    .rowOddBackground(Color(.systemGray6))
    .border(Color(.separator), width: 1)
    .cornerRadius(8)
    .cellPadding(horizontal: 14, vertical: 10)
    .alignment(.center)
}
```

Line height defaults to `20`, cell color to `.primary`, and margin bottom to `16`.

The cell font has no text-style default. Left unset, cells use the **paragraph's face at a fixed `14` pt**, so default table text does not scale with Dynamic Type; set `.font(_:)` with a text style to make it scale. Because there is no cell font until you set one, `.bold()`, `.fontWeight(_:)`, `.italic(_:)`, and `.fontDesign(_:)` on `Table()` only take effect alongside a `.font` modifier in the same or a lower layer. The header row is **always bold**: the renderer bolds whatever header font it ends up with - `.headerFont(_:)`, or the cell font - and there is no modifier to turn that off.

:::note
`.alignment(_:)` places the **whole table** when it is narrower than the surrounding text - it is not column alignment, which comes from the Markdown separator row alone. It takes SwiftUI's `HorizontalAlignment`, but only `.leading`, `.center`, and `.trailing` mean anything: any other alignment logs a warning and leaves the inherited value. A table wider than the text scrolls horizontally and ignores this. `Table()` also accepts the shared `.multilineTextAlignment(_:)` because it shares the base element protocol, but nothing reads it.
:::

### `CodeBlock()` {#codeblock}

Fenced code blocks. Takes the [shared modifiers](#shared-modifiers) - including `.bold()`, `.fontWeight(_:)`, `.italic(_:)`, `.fontDesign(_:)`, and `.multilineTextAlignment(_:)` - plus the block-specific ones below:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.font(_:)` | `Font` | `.system(.body, design: .monospaced)` | Text style for the code |
| `.font(custom name:size:)` | `String`, `CGFloat` | unset | A registered family at a fixed size |
| `.font(size:weight:design:)` | `CGFloat`, `Font.Weight`, `Font.Design?` | unset | A fixed system size |
| `.foregroundStyle(_:)` | `Color \| semantic` | `.primary` | Code color |
| `.background(_:)` | `Color \| semantic` | `.quaternary` | Fill behind the block |
| `.padding(_:)` | `CGFloat` | `12` | Space between the fill's edge and the code |
| `.cornerRadius(_:)` | `CGFloat` | `8` | Rounds the fill |
| `.border(_:width:)` | `Color \| semantic`, `CGFloat?` | `#38404A`, `1` | Outline around the fill, and optionally its thickness. Left unset, the renderer draws a **fixed** dark-gray `1` pt outline |
| `.border(width:)` | `CGFloat` | `1` | Thickness alone, keeping the color a lower layer set. `0` removes the outline |
| `.lineHeight(_:)` | `CGFloat` | unset | Line height in points |
| `.marginTop(_:)` / `.marginBottom(_:)` | `CGFloat` | unset / `16` | Space above and below |
| `.headerForegroundStyle(_:)` | `Color \| semantic` | unset | Language label and copy button of a [scrollable panel](/ios/api-reference/enriched-markdown-text#markdowncodeblocklayout). Unset, they take the code color at 60% opacity |

```swift
MarkdownTheme {
  CodeBlock()
    .font(custom: "JetBrainsMono-Regular", size: 13)
    .background(Color(.secondarySystemBackground))
    .border(Color(.separator), width: 1)
    .cornerRadius(10)
    .padding(14)
}
```

A block keeps the monospaced design unless you replace it explicitly: `.font(.body)` re-sizes the monospaced face, while `.font(.system(.body, design: .serif))` or `.font(custom:size:)` gives you the face you named.

The default outline is a fixed color that does not adapt to dark mode. To match your palette, set `.border(_:width:)` yourself, or `.border(width: 0)` to drop it.

The scrollable panel's header font is not themable: the language label is always the system font, medium weight, at 85% of the code font's size.

Code is drawn in a single color by default. To color it by the fence's language, add the `EnrichedMarkdownSyntaxHighlighting` product - see [Syntax highlighting](/ios/guides/syntax-highlighting) - and style the token colors with [`SyntaxToken(_:)`](#syntaxtoken).

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

Leaving the font unset is what keeps inline code the size of the line it sits in - inline code in a heading is heading-sized. In that case it is always the **system monospaced** face at the line's size, never the paragraph's family. Passing **any** font - `.font(.body)`, `.font(size:weight:design:)`, or `.font(custom:size:)` - replaces that with exactly the font you gave, pinned to that size everywhere. For the same reason, `.bold()`, `.fontWeight(_:)`, `.italic(_:)`, and `.fontDesign(_:)` on `Code()` do nothing without a `.font` modifier - including the default `.fontDesign(.monospaced)`, which is listed for completeness: the monospaced face comes from the renderer.

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

A tapped link goes through the [`openURL`](/ios/api-reference/enriched-markdown-text#openurl) environment action, which opens it with the system unless you install your own.

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

Underlined text, from `_text_` and `__text__` with `MarkdownParsingOptions(underline: true)`. Takes the [shared modifiers](#shared-modifiers); nothing set by default.

```swift
EnrichedMarkdownText(content, options: MarkdownParsingOptions(underline: true))
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

`==text==` with `MarkdownParsingOptions(highlight: true)`. Takes the [shared modifiers](#shared-modifiers) plus:

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
| `.foregroundStyle(_:)` | `Color \| semantic` | `.secondary` | The particles, or the fill of the solid box |
| `.background(_:)` | `Color \| semantic` | `systemBackground` | Backdrop painted under the particles, hiding the text through the gaps. The solid overlay ignores it |

```swift
EnrichedMarkdownText(content)
  .markdownSpoilerOverlay(.particles(density: 16, speed: 30))
  .markdownTheme {
    Spoiler()
      .foregroundStyle(.secondary)
  }
```

The theme sets the spoiler's **colors**; how the overlay behaves is tuned on the overlay itself. Density and speed are arguments of [`.markdownSpoilerOverlay(.particles(density:speed:))`](/ios/api-reference/enriched-markdown-text#markdownspoileroverlay), in absolute units - particles per 100×100 pt and points per second - not multipliers: `density: 16` is twice as dense as the default `8`, and `speed: 40` drifts twice as fast as the default `20`. The solid overlay's corner radius is an argument of `.solid(cornerRadius:)` and is an **absolute** value in points, `4` by default.

For an overlay of your own design, see [Custom spoiler overlays](/ios/api-reference/enriched-markdown-text#custom-spoiler-overlays); it receives the same `Spoiler()` colors.

### `BlockImage()` {#blockimage}

An image alone in its paragraph. No font or color - it is sized, rounded, and spaced:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.height(_:)` | `CGFloat` | `200` | A **fixed** box height in points; the box spans the container width |
| `.maxHeight(_:)` | `CGFloat` | unset | The image's own proportions at the available width, capped at this height |
| `.aspectRatio(_:)` | `CGFloat` or `CGSize` | unset | Sizes the box from the available width and a width-over-height ratio, e.g. `16 / 9` |
| `.aspectRatio(_:contentMode:)` | `CGFloat`, `ImageContentMode` | unset | Both at once - the ratio shapes the box, the mode places the image in it |
| `.contentMode(_:)` | `ImageContentMode` | see below | How the bitmap fills that box |
| `.cornerRadius(_:)` | `CGFloat` | `8` | Rounds the image |
| `.marginTop(_:)` | `CGFloat` | unset | Overrides the paragraph margin above an image-only paragraph |
| `.marginBottom(_:)` | `CGFloat` | `16` | Overrides the paragraph margin below it |

```swift
MarkdownTheme {
  BlockImage()
    .aspectRatio(16 / 9, contentMode: .fill)
    .cornerRadius(12)
    .marginBottom(24)
}
```

The box is always as wide as the available width - there is no width modifier - so the sizing modifiers decide only its **height**:

- `.height(_:)` - a fixed height, whatever the image's proportions. This is what the default theme sets, at `200`.
- `.maxHeight(_:)` - the height that keeps the image's own proportions at the available width, capped at the value. Until the image has loaded, the box stands at the cap.
- `.aspectRatio(_:)` - the available width divided by the ratio, so `16 / 9` gives a widescreen box. The `CGSize` overload takes `width / height` of the size you pass.

The three are **mutually exclusive**: a theme sets exactly one, the last one applied wins, and a layer that sets any sizing replaces the lower layer's - a `.maxHeight(400)` layered over the default `.height(200)` leaves no fixed height behind.

`.contentMode(_:)` places the bitmap inside that box. It takes an `ImageContentMode`:

| Case | Draws the image |
| --- | --- |
| `.fit` | Scaled to fit inside the box, keeping its proportions. Never cropped |
| `.fill` | Scaled to fill the box, keeping its proportions. Overflow is cropped |
| `.stretch` | Stretched to fill the box exactly, ignoring its proportions |
| `.scaleDown` | Centered at its own size, scaled down only when it is larger than the box |
| `.original` | Centered at its own size, never scaled. Overflow is cropped |
| `.fitWidth` | Scaled to the box's width and centered vertically. Overflow is cropped |

Left unset it follows the sizing: a fixed `height` box draws `.fitWidth`, and a `maxHeight` or `aspectRatio` box `.fill`. Unlike SwiftUI's `.aspectRatio(_:contentMode:)`, the ratio here shapes the **box** and the mode places the image in it.

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
| `.foregroundStyle(_:)` | `Color \| semantic` | `.secondary` | Color of the rule |
| `.height(_:)` | `CGFloat` | `1` | Thickness of the rule |
| `.marginTop(_:)` / `.marginBottom(_:)` | `CGFloat` | `24` / `24` | Space above and below |

```swift
MarkdownTheme {
  ThematicBreak()
    .foregroundStyle(Color(.separator))
    .height(2)
    .marginTop(32)
    .marginBottom(32)
}
```

### `SyntaxToken(_ type: SyntaxTokenType)` {#syntaxtoken}

The color of **one** token type inside a syntax-highlighted code block. It ships with the `EnrichedMarkdownSyntaxHighlighting` product, so it needs that import, and it only has an effect where highlighting is turned on with `.markdownSyntaxHighlighting()` - see [Syntax highlighting](/ios/guides/syntax-highlighting). One modifier:

| Modifier | Type | Default | Description |
| --- | --- | --- | --- |
| `.foregroundStyle(_:)` | `Color \| semantic` | per type, see below | Color of every token of that type |

Color is the whole surface: a token keeps the [`CodeBlock()`](#codeblock) font, and there is no per-token weight, slant, or background.

```swift
import EnrichedMarkdown
import EnrichedMarkdownSyntaxHighlighting
import SwiftUI

struct CodeSampleView: View {
  let markdown: String

  var body: some View {
    EnrichedMarkdownText(markdown)
      .markdownSyntaxHighlighting()
      .markdownTheme {
        SyntaxToken(.keyword).foregroundStyle(.pink)
        SyntaxToken(.comment).foregroundStyle(.secondary)
      }
  }
}
```

`SyntaxTokenType` has fourteen cases: `.keyword`, `.operator`, `.punctuation`, `.string`, `.number`, `.constant`, `.comment`, `.function`, `.type`, `.variable`, `.property`, `.tag`, `.attribute`, and `.embedded`.

Turning highlighting on layers `MarkdownTheme.syntaxHighlightingDefault` - GitHub's palette - above `MarkdownTheme.default` and below your own themes, so a `SyntaxToken` you set overrides one type and leaves the rest. The palette switches between light and dark with the color scheme:

| Type | Light | Dark |
| --- | --- | --- |
| `.keyword` | `#CF222E` | `#FF7B72` |
| `.string` | `#0A3069` | `#A5D6FF` |
| `.number`, `.constant`, `.property`, `.attribute` | `#0550AE` | `#79C0FF` |
| `.comment` | `#6E7781` | `#8B949E` |
| `.function` | `#8250DF` | `#D2A8FF` |
| `.type` | `#953800` | `#FFA657` |
| `.tag` | `#116329` | `#7EE787` |

`.operator`, `.punctuation`, `.variable`, and `.embedded` have no default color, so they keep the code block's color until you give them one.

## See also

- [`MarkdownTheme`](/ios/api-reference/markdown-theme) - building, providing, and layering themes.
- [Element structure](/ios/api-reference/element-structure) - what each Markdown construct renders as.
- [Custom fonts](/ios/guides/custom-fonts) - `.font(custom:size:)`, bold faces, and Dynamic Type.
- [Syntax highlighting](/ios/guides/syntax-highlighting) - turning code-block highlighting on.
