---
sidebar_label: Custom fonts
sidebar_position: 4
---

# Custom fonts

Pointing an element at your own typeface is one modifier:

```swift
MarkdownTheme {
  Paragraph().font(custom: "Inter-Regular", size: 17)
  Heading(1).font(custom: "Inter-Bold", size: 34)
}
```

The rest of this page is about the three things that go wrong afterwards: **a name that does not resolve fails silently**, **bold and italic need their own faces**, and **a custom family stops following Dynamic Type**.

## How a name is resolved

`.font(custom name: String, size: CGFloat)` takes a **PostScript name** - `Inter-SemiBold`, not `Inter Semi Bold` - and resolves it in three steps:

1. `UIFont(name:size:)`, which finds any font the system already knows: a system family, or one declared in your `Info.plist` under `UIAppFonts`.
2. If that misses, the package looks in `Bundle.main` for a file named after it, in this order: `Fonts/<name>.ttf`, `<name>.ttf`, `Fonts/<name>.otf`, `<name>.otf`. It registers the first one it finds with CoreText for the current process, then retries step 1.
3. If it still misses, it falls back to the **system font** at the requested size, with a weight guessed from the name - a name containing `semibold`, `bold`, `medium`, `light`, `thin`, `black`, or `heavy` gets that weight. Italic is **not** guessed: `Inter-Italic` falls back to an upright system font.

Step 2 is the convenient part: a font file named exactly after its PostScript name works without an `Info.plist` entry. Step 3 is the dangerous part.

:::caution
**A misspelled font name does not fail.** It renders as the system font at the right size and roughly the right weight, which on a phone screen looks like a slightly-off design rather than a bug. If a family "isn't applying", check the PostScript name first - Font Book shows it, and so does `UIFont.fontNames(forFamilyName:)`.
:::

Step 1 runs on every render, so a font your app registers itself later - with `CTFontManagerRegisterFontsForURL`, say - is picked up by the next render. Only step 2, the package's own bundle search, is attempted **once per name per process**: if the file was not in the bundle the first time, the package does not look again.

## Bold and italic

Markdown's `**bold**` and `*italic*` do not carry a font of their own - the renderer takes the font of the surrounding block and asks for a bolder or slanted face of the **same family**. It looks through the faces actually registered for that family and picks the best match.

So bold text inside a paragraph set to `Inter-Regular` renders in `Inter-Bold` only if `Inter-Bold` is also registered. The two differ in what happens when there is no matching face:

- **Bold** keeps the original face rather than faking one, so a single-weight family renders `**bold**` **identically to body text**.
- **Italic** is synthesized as a slant, so `*italic*` still reads as italic even in a family with no italic face - just not as the designer drew it.

Ship every face you rely on, or accept that bold will not be visible.

The `.bold()` and `.italic()` modifiers follow the same rules on a custom family. On a *system* font they always work, because the system has every weight.

`.fontWeight(_:)` is coarser on a custom family: it cannot pick an arbitrary face, only switch to the bold one. `.semibold` and heavier ask for the family's bold face, under the rule above; anything lighter - `.medium`, `.light`, `.thin` - is **ignored**. To use `Inter-Medium`, name it in `.font(custom:size:)`.

:::note
`.fontDesign(_:)` applies to system fonts only. Combined with `.font(custom:size:)`, it is ignored - the family you named is the family you get.
:::

## Dynamic Type

This is the trade-off that is easiest to miss:

| Modifier | Scales with Dynamic Type |
| --- | --- |
| `.font(.body)`, `.font(.largeTitle)`, any SwiftUI text style | **Yes** |
| `.font(custom: "Inter-Regular", size: 17)` | No - `17` at every text size |
| `.font(size: 17)` | No |

`MarkdownTheme.default` uses text styles throughout, so the built-in look scales - except table cells, which default to the paragraph face at a fixed `14` pt (see [`Table()`](/ios/api-reference/style-properties#table)). The moment you set a family, that element is pinned - and an app that pins every element has opted its Markdown out of an accessibility feature its other screens still have.

If you want both, scale the size yourself with `UIFontMetrics` and [build the theme in `body`](/ios/api-reference/markdown-theme#environment-themes). Read `dynamicTypeSize` from the environment and pass it to `UIFontMetrics` as a trait collection: that way SwiftUI re-evaluates `body` when the text size changes, and the scaling honors a `.dynamicTypeSize(_:)` cap set anywhere above the view rather than the device setting alone:

```swift
import EnrichedMarkdown
import SwiftUI
import UIKit

struct ArticleView: View {
  let markdown: String
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
    let bodySize = UIFontMetrics(forTextStyle: .body).scaledValue(for: 17, compatibleWith: traits)
    let titleSize = UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: 34, compatibleWith: traits)

    EnrichedMarkdownText(markdown)
      .markdownTheme {
        Paragraph().font(custom: "Inter-Regular", size: bodySize)
        Heading(1).font(custom: "Inter-Bold", size: titleSize)
      }
  }
}
```

## Which elements take a family

`.font(custom:size:)` takes effect on the elements that have a font of their own: `Paragraph`, `Heading`, `Blockquote`, `List`, `Table`, `Code`, and `CodeBlock`. `Table()` additionally takes `.headerFont(custom:size:)` for the header row alone.

:::caution
`Link`, `Strong`, `Emphasis`, `Strikethrough`, `Underline`, and `Highlight` **accept** `.font(custom:size:)` - it compiles - but it does nothing: these elements always render in the font of the block they sit in. The same goes for every other font modifier on them. To change how links or bold text look, set the family on the block (`Paragraph`, `Heading`, …) and register its bold and italic faces.
:::

The rest - `TaskList`, `BlockImage`, `InlineImage`, `ThematicBreak`, `Spoiler`, `Admonition`, `Superscript`, `Subscript` - have no font to set. They either draw no text, or scale with the text around them.

The **table header row is always bold**: the renderer asks for the bold variant of the header font - `.headerFont(custom:size:)`, or the cell font when that is unset - and there is no modifier to turn that off. A family with no bold face shows no difference between header and cells.

Two fonts are worth setting deliberately:

- **`CodeBlock()`** stays monospaced unless you give it a family. Pass one and you get exactly that face, proportional or not.
- **`Code()`** (inline) deliberately has **no** font by default, so it renders in the system monospaced face at the size of the line it sits in. It never inherits the paragraph's family. **Any** font you give it - a family, a fixed size, or a text style like `.font(.body)` - replaces that with exactly that font, pinned to that size everywhere, including inside headings.

## See also

- [Style properties](/ios/api-reference/style-properties#shared-modifiers) - the full modifier list per element, and [which ones each element honors](/ios/api-reference/style-properties#honored-modifiers).
- [Style properties](/ios/api-reference/style-properties#adaptive-values) - which theme values adapt to appearance and text size.
