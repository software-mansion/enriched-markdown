---
sidebar_label: MarkdownTheme
sidebar_position: 2
---

# MarkdownTheme

This page covers the types that **build and provide** themes. For the styleable elements and their modifiers, see [Style properties](/ios/api-reference/style-properties).

A theme reaches a view through the SwiftUI environment. `MarkdownTheme.default` is always at the bottom of the stack; every `.markdownTheme` you apply adds a layer on top of it, and the view flattens the stack when it renders. Apply one near the top of your UI and add a layer lower down only where something has to differ.

## `.markdownTheme` {#markdowntheme}

```swift
extension View {
  func markdownTheme(_ theme: MarkdownTheme) -> some View
  func markdownTheme(@MarkdownThemeBuilder _ content: () -> MarkdownThemeGroup) -> some View
}
```

Adds `theme` as a layer for everything in the subtree. The builder overload is shorthand for wrapping the same content in a `MarkdownTheme` - useful for a one-off override:

```swift
NavigationStack {
  ArticleList()

  ChatBubble(markdown: message)
    .markdownTheme { Paragraph().marginBottom(4) }  // compact, this view only
}
.markdownTheme(appTheme)                             // the default everywhere below
```

Layers **append**, they do not replace. The chat bubble above still gets every property `appTheme` set - it only overrides `Paragraph`'s bottom margin. Layering applies per property, not per element: a lower layer's `Paragraph().font(.body)` survives an upper layer that sets only `Paragraph().foregroundStyle(.secondary)`.

## `MarkdownTheme`

```swift
public struct MarkdownTheme: Sendable {
  public init(@MarkdownThemeBuilder _ content: () -> MarkdownThemeGroup)
  public static let `default`: MarkdownTheme
}
```

A group of element overrides, built with a result builder. Each statement in the closure is one element:

```swift
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

### `MarkdownTheme.default`

The built-in look: system text styles throughout, semantic colors that follow light and dark mode, GitHub's alert palette, and the margins listed under each element in [Style properties](/ios/api-reference/style-properties). It is always the bottom layer, which is why `EnrichedMarkdownText` renders sensibly with no theme at all.

## Themes that branch on the environment {#environment-themes}

When the **builder itself branches** on the appearance or the text size, build the theme in `body` and read the environment values in the view. SwiftUI re-evaluates `body` when they change, so the theme is rebuilt with them - there is nothing extra to call:

```swift
struct RootView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    Content()
      .markdownTheme {
        Heading(1).foregroundStyle(colorScheme == .dark ? brandLight : brandDark)
        if dynamicTypeSize.isAccessibilitySize {
          Paragraph().lineHeight(34)
        }
      }
  }
}
```

:::note
`rememberMarkdownTheme(colorScheme:dynamicTypeSize:)` did this in 0.1. It still compiles and carries no deprecation warning, but it now ignores both arguments and simply builds the theme - so it is equivalent to a plain `MarkdownTheme { … }`, or to the `.markdownTheme { … }` builder overload above. Prefer either of those in new code.
:::

A theme that does **not** branch does not need any of this - see below.

## Light, dark, and Dynamic Type {#appearance}

Themes are stored as unresolved specs: fonts and colors are produced only when a view renders, against a trait collection built from that view's own `colorScheme` and `dynamicTypeSize`. Resolution is per render rather than per theme, which is why a theme hoisted to a `let` at file scope still adapts to both.

How far it adapts depends on the values you gave it - see [Dark mode and Dynamic Type](/ios/api-reference/style-properties#adaptive-values) for which ones follow the appearance and the text size, which are frozen, and how to cap how far text scales.

## `MarkdownStyleConfig`

```swift
public struct MarkdownStyleConfig: Equatable, Sendable {
  public static func resolve(
    layers: [MarkdownTheme],
    traitCollection: UITraitCollection
  ) -> MarkdownStyleConfig

  public static func baseline(traitCollection: UITraitCollection = .current) -> MarkdownStyleConfig
}
```

A theme flattened into concrete `UIFont`s, `UIColor`s, and lengths - the form the renderer actually consumes. `EnrichedMarkdownText` builds one for you; you need it only when calling [`MarkdownRenderer`](#markdownrenderer) directly.

- **`resolve(layers:traitCollection:)`** folds the layers left to right, each overriding only the properties it sets. Put `.default` first unless you genuinely want to start from nothing.
- **`baseline(traitCollection:)`** is `resolve(layers: [.default], …)` - the built-in look, ready to use or to tweak field by field.

Every field is public and optional, so a config can also be adjusted after resolving, which is often the shortest path in a test:

```swift
var config = MarkdownStyleConfig.baseline()
config.blockquote.borderWidth = 6
```

## `MarkdownRenderer` {#markdownrenderer}

```swift
public enum MarkdownRenderer {
  public static func render(
    _ markdown: String,
    config: MarkdownStyleConfig,
    flags: Md4cFlags = .commonMark,
    imageRequestHeaders: [String: String] = [:]
  ) -> NSAttributedString
}
```

Renders a document to an `NSAttributedString` without a view - the escape hatch for tests and for one-off attributed text.

```swift
let text = MarkdownRenderer.render(
  "# Title\n\nBody with **bold**.",
  config: .baseline()
)
```

:::caution
The attributed string is **not the whole rendering**. List bullets and numbers, task list checkboxes, blockquote and admonition bars, code block backgrounds, and spoiler overlays are drawn by `EnrichedMarkdownText` around the text, not stored as attributes - so dropping this string into a plain `UITextView` gives you the text without them. See [UIKit interop](/ios/guides/uikit-interop) for what survives and what to do instead.
:::

`EnrichedMarkdownLaTeX` adds a `renderLaTeX` counterpart with math typesetting installed - see [LaTeX math](/ios/guides/latex-math#rendering-without-a-view).

## Performance notes

- **Hoist the themes that can be hoisted.** Building one inside a `body` allocates a fresh `MarkdownTheme` on every evaluation, and a changed theme re-resolves the config and re-renders the document. A `let` at file scope keeps that from happening on every frame; reserve the in-`body` form for themes that genuinely [branch on the environment](#environment-themes).
- **Re-resolving is cheap; re-rendering is not.** The view re-parses and re-renders when the markdown, the parsing options, the image headers, or the resolved config change - the last of which includes a Dynamic Type or appearance switch. That work happens off the main thread, but a theme that changes identity every frame will keep it running.

## See also

- [Style properties](/ios/api-reference/style-properties) - the elements and modifiers you can set.
- [`EnrichedMarkdownText`](/ios/api-reference/enriched-markdown-text) - the view and its modifiers.
- [Custom fonts](/ios/guides/custom-fonts) - how `.font(custom:size:)` resolves a face.
