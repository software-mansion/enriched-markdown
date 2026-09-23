---
sidebar_label: Custom fonts
sidebar_position: 4
---

# Custom fonts

Pointing an element at your own typeface is one modifier:

```swift
MarkdownTheme {
  Paragraph().fontFamily("Inter-Regular", size: 17)
  Heading(1).fontFamily("Inter-Bold", size: 34)
}
```

The rest of this page is about the three things that go wrong afterwards: **a name that does not resolve fails silently**, **bold and italic need their own faces**, and **a custom family stops following Dynamic Type**.

## How a name is resolved

`.fontFamily(_ name: String, size: CGFloat)` takes a **PostScript name** - `Inter-SemiBold`, not `Inter Semi Bold` - and resolves it in three steps:

1. `UIFont(name:size:)`, which finds any font the system already knows: a system family, or one declared in your `Info.plist` under `UIAppFonts`.
2. If that misses, the package looks in `Bundle.main` for `<name>.ttf` or `<name>.otf`, first in a `Fonts/` subdirectory and then at the bundle root, and registers what it finds with CoreText for the current process. Then it retries step 1.
3. If it still misses, it falls back to the **system font** at the requested size, with a weight guessed from the name - a name containing `semibold`, `bold`, `medium`, `light`, `thin`, `black`, or `heavy` gets that weight.

Step 2 is the convenient part: a font file named exactly after its PostScript name works without an `Info.plist` entry. Step 3 is the dangerous part.

:::caution
**A misspelled font name does not fail.** It renders as the system font at the right size and roughly the right weight, which on a phone screen looks like a slightly-off design rather than a bug. If a family "isn't applying", check the PostScript name first - Font Book shows it, and so does `UIFont.fontNames(forFamilyName:)`.
:::

A bundle lookup is attempted **once per name per process**. Registering the file later at runtime will not be picked up by an element that already missed; register your fonts before the first render, or declare them in `Info.plist`.

## Bold and italic

Markdown's `**bold**` and `*italic*` do not carry a font of their own - the renderer takes the font of the surrounding block and asks for a bolder or slanted face of the **same family**. It looks through the faces actually registered for that family and picks the best match.

So bold text inside a paragraph set to `Inter-Regular` renders in `Inter-Bold` only if `Inter-Bold` is also registered. When no matching face exists, the renderer keeps the original face rather than faking one - which means:

- A single-weight family renders `**bold**` **identically to body text**.
- A family with no italic face renders `*italic*` **upright**.

Ship every face you rely on, or accept that emphasis will not be visible.

The `.bold()` modifier follows the same rule on a custom family: it asks for a bold face and keeps the original if there is none. On a *system* font it always works, because the system has every weight.

:::note
`.fontDesign(_:)` applies to system fonts only. Combined with `.fontFamily`, it is ignored - the family you named is the family you get.
:::

## Dynamic Type

This is the trade-off that is easiest to miss:

| Modifier | Scales with Dynamic Type |
| --- | --- |
| `.font(.body)`, `.font(.largeTitle)`, any SwiftUI text style | **Yes** |
| `.fontFamily("Inter-Regular", size: 17)` | No - `17` at every text size |
| `.fontSize(17)` | No |

`MarkdownTheme.default` uses text styles throughout, so the built-in look scales. The moment you set a family, that element is pinned - and an app that pins every element has opted its Markdown out of an accessibility feature its other screens still have.

If you want both, scale the size yourself and rebuild the theme when the text size changes. `UIFontMetrics` does the scaling, and [`rememberMarkdownTheme`](/ios/api-reference/markdown-theme#remembermarkdowntheme) does the rebuilding:

```swift
struct RootView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    let body = UIFontMetrics(forTextStyle: .body).scaledValue(for: 17)
    let title = UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: 34)

    let theme = rememberMarkdownTheme(
      colorScheme: colorScheme,
      dynamicTypeSize: dynamicTypeSize
    ) {
      Paragraph().fontFamily("Inter-Regular", size: body)
      Heading(1).fontFamily("Inter-Bold", size: title)
    }

    Content()
      .markdownTheme(theme)
  }
}
```

## Which elements take a family

`.fontFamily(_:size:)` is available on every element that has a font of its own: `Paragraph`, `Heading`, `Blockquote`, `List`, `Table`, `Code`, `CodeBlock`, `Link`, `Strong`, `Emphasis`, `Strikethrough`, `Underline`, and `Highlight`. `Table()` additionally takes `.headerFontFamily(_:size:)` for the header row alone.

The rest - `TaskList`, `BlockImage`, `InlineImage`, `ThematicBreak`, `Spoiler`, `Admonition`, `Superscript`, `Subscript` - have no font to set. They either draw no text, or scale with the text around them.

Two fonts are worth setting deliberately:

- **`CodeBlock()`** stays monospaced unless you give it a family. Pass one and you get exactly that face, proportional or not.
- **`Code()`** (inline) deliberately has **no** font by default, so it takes the size of the line it sits in. Giving it a family pins inline code to that size everywhere, including inside headings.

## See also

- [Style properties](/ios/api-reference/style-properties#shared-modifiers) - the full modifier list per element.
- [`MarkdownTheme`](/ios/api-reference/markdown-theme#appearance) - which theme values adapt to appearance and text size.
