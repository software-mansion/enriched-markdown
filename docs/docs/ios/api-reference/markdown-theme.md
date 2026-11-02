---
sidebar_label: MarkdownTheme
sidebar_position: 2
---

# MarkdownTheme

This page covers the types that **build and provide** themes. For the styleable elements and their modifiers, see [Style properties](/ios/api-reference/style-properties).

A theme reaches a view through the SwiftUI environment. By default, `MarkdownTheme.default` is at the bottom of the stack; every `.markdownTheme` you apply adds a layer on top of it, and the view flattens the stack when it renders. Apply one near the top of your UI and add a layer lower down only where something has to differ.

## `.markdownTheme` {#markdowntheme}

```swift
extension View {
  func markdownTheme(_ theme: MarkdownTheme) -> some View
  func markdownTheme(@MarkdownThemeBuilder _ content: () -> MarkdownThemeGroup) -> some View
}
```

Adds `theme` as a layer for everything in the subtree. The builder overload is shorthand for wrapping the same content in a `MarkdownTheme` - useful for a one-off override:

```swift
import EnrichedMarkdown
import SwiftUI

let appTheme = MarkdownTheme {
  Paragraph().font(.body).marginBottom(16)
}

struct InboxView: View {
  let article: String
  let message: String

  var body: some View {
    NavigationStack {
      ScrollView {
        EnrichedMarkdownText(article)

        EnrichedMarkdownText(message)
          .markdownTheme { Paragraph().marginBottom(4) }  // compact, this view only
      }
    }
    .markdownTheme(appTheme)                               // the default everywhere below
  }
}
```

Layers **append**, they do not replace. The message above still gets every property `appTheme` set - it only overrides `Paragraph`'s bottom margin. Layering applies per property, not per element: a lower layer's `Paragraph().font(.body)` survives an upper layer that sets only `Paragraph().foregroundStyle(.secondary)`.

### `markdownThemeLayers` {#markdownthemelayers}

```swift
extension EnvironmentValues {
  var markdownThemeLayers: [MarkdownTheme] { get set }  // [.default] unless you set it
}
```

The stack itself is a public environment value. `.markdownTheme` appends to it; setting it directly **replaces** it, `.default` included. That is the escape hatch when you want to start from a base of your own rather than from the built-in look:

```swift
ContentView()
  .environment(\.markdownThemeLayers, [houseBaseTheme])  // no MarkdownTheme.default underneath
```

Anything you leave unset is then unstyled, so a replacement base has to cover every element you render. `.markdownTheme` calls further down still append to it.

Optional products install their own defaults as well: `.markdownLaTeX()` adds `MarkdownTheme.latexDefault` and `.markdownSyntaxHighlighting()` adds `MarkdownTheme.syntaxHighlightingDefault`. The view inserts those right above the **first** layer of the stack - `.default`, or your replacement base - and below every theme you applied, so your own overrides always win.

## `MarkdownTheme` {#markdowntheme-type}

```swift
public struct MarkdownTheme: Sendable {
  public init(@MarkdownThemeBuilder _ content: () -> MarkdownThemeGroup)
  public static let `default`: MarkdownTheme
}
```

A group of element overrides, built with a result builder. Each statement in the closure is one element:

```swift
import EnrichedMarkdown
import SwiftUI

let appTheme = MarkdownTheme {
  Paragraph()
    .font(.body)
    .lineHeight(26)
    .marginBottom(16)

  Heading(1).font(.largeTitle).bold()

  Link().foregroundStyle(.tint).underline()

  CodeBlock()
    .font(.system(.body, design: .monospaced))
    .background(Color(.secondarySystemBackground))
    .cornerRadius(8)
    .padding(16)
}
```

Being a result builder, the closure also takes `if` / `else` and `for` loops, so a theme can branch on a feature flag without building two of them.

### Reusing parts of a theme {#reusing-parts}

A `MarkdownTheme` cannot be placed inside another one's builder - it is a finished layer, not builder content. To share a block of elements between themes, factor it out as a `MarkdownThemeGroup`, which is what the builder produces and which can be used as a statement in any other builder:

```swift
import EnrichedMarkdown
import SwiftUI

@MarkdownThemeBuilder
var brandHeadings: MarkdownThemeGroup {
  Heading(1).font(.largeTitle).bold().foregroundStyle(.indigo)
  Heading(2).font(.title).bold().foregroundStyle(.indigo)
}

let articleTheme = MarkdownTheme {
  brandHeadings
  Paragraph().lineHeight(28)
}

let chatTheme = MarkdownTheme {
  brandHeadings
  Paragraph().marginBottom(4)
}
```

The builder accepts anything conforming to `MarkdownThemeContent`: the element types from [Style properties](/ios/api-reference/style-properties), `MarkdownThemeGroup`, and the elements of the optional products (`MathBlock()`, `InlineMath()`, `SyntaxToken(_:)`). To combine two whole themes, apply both - as two `.markdownTheme` layers, or as two entries in `resolve(layers:)`.

### `MarkdownTheme.default` {#markdownthemedefault}

The built-in look: system text styles throughout, mostly semantic colors that follow light and dark mode, GitHub's alert palette, and the margins listed under each element in [Style properties](/ios/api-reference/style-properties). By default it is the bottom layer, which is why `EnrichedMarkdownText` renders sensibly with no theme at all.

Not every default adapts to the appearance. These are fixed colors, the same in light and dark mode:

- the `Highlight()` background, `#FEF08A`;
- the five `Admonition` colors, GitHub's light-mode palette (`#0969DA`, `#1A7F37`, `#8250DF`, `#9A6700`, `#CF222E`);
- the `TaskList()` checkmark, white.

Two more come from the renderer rather than the theme, because `.default` leaves them unset: a blockquote is filled with a fixed near-white `#FAFAFC`, and a code block gets a fixed 1pt `#38404A` border. Neither follows dark mode. If your app supports dark mode, set `Blockquote().background(…)` and the `CodeBlock()` border in your own theme with adaptive colors.

## Themes that branch on the environment {#environment-themes}

When the **builder itself branches** on the appearance or the text size, build the theme in `body` and read the environment values in the view. SwiftUI re-evaluates `body` when they change, so the theme is rebuilt with them - there is nothing extra to call:

```swift
import EnrichedMarkdown
import SwiftUI

struct RootView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  let markdown: String

  var body: some View {
    EnrichedMarkdownText(markdown)
      .markdownTheme {
        Heading(1).foregroundStyle(colorScheme == .dark ? Color.mint : Color.teal)
        if dynamicTypeSize.isAccessibilitySize {
          Paragraph().lineHeight(34)
        }
      }
  }
}
```

:::note
`rememberMarkdownTheme(colorScheme:dynamicTypeSize:_:)` is deprecated in 0.4.0 and ignores both arguments. Replace it with a plain `MarkdownTheme { … }` built in `body`, or the `.markdownTheme { … }` overload above.
:::

A theme that does **not** branch does not need any of this - see below.

## Light, dark, and Dynamic Type {#appearance}

Themes are stored as unresolved specs: fonts and colors are produced only when a view renders, against a trait collection built from that view's own `colorScheme` and `dynamicTypeSize`. Resolution is per render rather than per theme, which is why a theme hoisted to a `let` at file scope still adapts to both.

How far it adapts depends on the values you gave it - see [Dark mode and Dynamic Type](/ios/api-reference/style-properties#adaptive-values) for which ones follow the appearance and the text size, which are frozen, and how to cap how far text scales. Some built-in defaults are fixed colors - see [`MarkdownTheme.default`](#markdownthemedefault).

## `MarkdownStyleConfiguration` {#markdownstyleconfiguration}

```swift
public struct MarkdownStyleConfiguration: Equatable, Sendable {
  public var paragraph: ElementStyle
  public var heading1: ElementStyle   // … through heading6
  public var codeBlock: CodeBlockStyle
  public var blockquote: BlockquoteStyle
  public var linkVariants: [LinkVariantStyle]   // one per Link(matching:) pattern
  // … one record per element: link, strong, emphasis, strikethrough, underline,
  // superscript, subscript, highlight, spoiler, code, image, inlineImage,
  // thematicBreak, list, taskList, table

  public init(/* every record, each defaulting to an empty one */)

  public static func resolve(
    layers: [MarkdownTheme],
    traitCollection: UITraitCollection
  ) -> MarkdownStyleConfiguration

  public static func baseline(traitCollection: UITraitCollection = .current) -> MarkdownStyleConfiguration
}
```

A theme flattened into concrete `UIFont`s, `UIColor`s, and lengths - the form the renderer actually consumes. `EnrichedMarkdownText` builds one for you; you need it only when calling [`MarkdownRenderer`](#markdownrenderer) directly.

- **`resolve(layers:traitCollection:)`** starts from an empty configuration and folds the layers left to right, each overriding only the properties it sets. Put `.default` first unless you genuinely want to start from nothing. Unlike the view, it adds no layers of its own: if you render with an optional product, include its default theme yourself (`[.default, .latexDefault, appTheme]`).
- **`baseline(traitCollection:)`** is `resolve(layers: [.default], …)` - the built-in look, ready to use or to tweak field by field.

Each element has a public record (`ElementStyle`, `CodeBlockStyle`, `BlockquoteStyle`, …), always present; the properties inside a record are optional, where `nil` means "not set" and the renderer falls back to its own value. `init()` with no arguments gives a configuration with nothing set. A config can be adjusted after resolving, which is often the shortest path in a test:

```swift
var config = MarkdownStyleConfiguration.baseline()
config.blockquote.borderWidth = 6
```

The styles of the optional products' elements - `MathBlock()`, `InlineMath()`, `SyntaxToken(_:)` - are not public fields. Set those through a theme layer and resolve.

## `MarkdownRenderer` {#markdownrenderer}

```swift
public enum MarkdownRenderer {
  public static func render(
    _ markdown: String,
    config: MarkdownStyleConfiguration,
    options: MarkdownParsingOptions = .commonMark,
    imageRequestHeaders: [String: String] = [:],
    writingDirection: MarkdownWritingDirection = .firstStrong,
    layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight,
    codeBlockLayout: MarkdownCodeBlockLayout = .wrapping
  ) -> NSAttributedString
}
```

Renders a document to an `NSAttributedString` without a view - the escape hatch for tests and for one-off attributed text.

```swift
import EnrichedMarkdown

let text = MarkdownRenderer.render(
  "# Title\n\nBody with **bold**.",
  config: .baseline()
)
```

#### `markdown`

The Markdown source to render.

<PropInfo type="String" required />

#### `config`

The resolved styles - see [`MarkdownStyleConfiguration`](#markdownstyleconfiguration).

<PropInfo type="MarkdownStyleConfiguration" required />

#### `options`

The parser extensions to enable, as on the view - see [`options`](/ios/api-reference/enriched-markdown-text#options).

<PropInfo type="MarkdownParsingOptions" default=".commonMark" />

#### `imageRequestHeaders`

HTTP headers sent with every remote image request.

<PropInfo type="[String: String]" default="[:]" />

#### `writingDirection`

How each paragraph's base direction is resolved - see [`.markdownWritingDirection`](/ios/api-reference/enriched-markdown-text#markdownwritingdirection) and [RTL and bidirectional text](/user-experience/rtl).

<PropInfo type="MarkdownWritingDirection" default=".firstStrong" />

#### `layoutDirection`

The interface direction that `.firstStrong` paragraphs without a strong directional character fall back to. A view supplies it from its environment; when rendering by hand, pass the hosting view's `effectiveUserInterfaceLayoutDirection`.

<PropInfo type="UIUserInterfaceLayoutDirection" default=".leftToRight" />

#### `codeBlockLayout`

Whether fenced code blocks wrap as selectable text or become horizontally scrolling panels - see [`.markdownCodeBlockLayout`](/ios/api-reference/enriched-markdown-text#markdowncodeblocklayout). With `.scrollable`, each code block is a text attachment whose panel only a TextKit 2 text view lays out.

<PropInfo type="MarkdownCodeBlockLayout" default=".wrapping" />

:::caution
The attributed string is **not the whole rendering**. List bullets and numbers, task list checkboxes, blockquote and admonition bars and icons, code block backgrounds, and spoiler overlays are drawn by `EnrichedMarkdownText` around the text, not stored as attributes - so dropping this string into a plain `UITextView` gives you the text without them. The string also ends at its last visible character: the last block's bottom margin is the view's to lay out (see [`.markdownBottomMargin`](/ios/api-reference/enriched-markdown-text#markdownbottommargin)), not part of the text. See [UIKit interop](/ios/guides/uikit-interop) for what survives and what to do instead.
:::

`render` runs no optional products: math stays as source text and code blocks are not colored, even with those products linked. `EnrichedMarkdownLaTeX` adds a `renderLaTeX` counterpart with math typesetting installed - see [LaTeX math](/ios/guides/latex-math#rendering-without-a-view) - and `EnrichedMarkdownSyntaxHighlighting` adds `renderSyntaxHighlighted` - see [Syntax highlighting](/ios/guides/syntax-highlighting).

## Performance notes

- **Re-rendering is gated on values, not identity.** The view re-parses and re-renders only when one of its inputs compares unequal to the last render's: the markdown, the resolved `MarkdownStyleConfiguration`, the parsing options, the image request headers, the installed render plugins (compared by type), the writing direction, the layout direction, or the code block layout. A theme rebuilt in `body` that resolves to the same values does **not** re-render the document. A Dynamic Type or appearance switch changes the resolved config, so it does.
- **Resolving runs on every `body` evaluation.** Each `EnrichedMarkdownText` flattens the whole layer stack whenever its `body` is evaluated. That is cheap next to a render, but a theme hoisted to a `let` at file scope also skips rebuilding the builder content each time - reserve the in-`body` form for themes that genuinely [branch on the environment](#environment-themes).
- **Keep inputs stable.** Rendering happens off the main thread, but a value that differs on every evaluation - a color computed from the current time, headers with a fresh token each frame - will keep it running.

## See also

- [Style properties](/ios/api-reference/style-properties) - the elements and modifiers you can set.
- [`EnrichedMarkdownText`](/ios/api-reference/enriched-markdown-text) - the view and its modifiers.
- [Custom fonts](/ios/guides/custom-fonts) - how `.font(custom:size:)` resolves a face.
