# Enriched Markdown iOS

Standalone SwiftUI library for rendering enriched Markdown on iOS. This package is separate from the React Native npm package and is distributed as a Swift Package (`EnrichedMarkdown`).

## Installation

Add the package via [Swift Package Manager](https://www.swift.org/documentation/package-manager/). The `Package.swift` lives at the repository root.

**Xcode:** File → Add Package Dependencies… → enter the repository URL, then select the `EnrichedMarkdown` product.

**Package.swift:**

```swift
dependencies: [
  .package(
    url: "https://github.com/software-mansion/react-native-enriched-markdown.git",
    branch: "main"
  ),
],
targets: [
  .target(
    name: "YourApp",
    dependencies: [
      .product(name: "EnrichedMarkdown", package: "EnrichedMarkdown"),
    ]
  ),
]
```

For local development, add a path dependency instead (as in [`apps/ios-example`](../../apps/ios-example)):

```swift
.package(path: "../react-native-enriched-markdown")
```

Requirements: **iOS 15+**, SwiftUI.

## Quick start

Render markdown with `EnrichedMarkdownText`. Styles come from the nearest `.markdownTheme` (defaults to `MarkdownTheme.default`):

```swift
import EnrichedMarkdown
import SwiftUI

struct ContentView: View {
  var body: some View {
    EnrichedMarkdownText("# Hello\n\nThis is **enriched** markdown.")
      .onLinkPress { url in
        UIApplication.shared.open(url)
      }
  }
}
```

See the full example in [`apps/ios-example`](../../apps/ios-example).

## Styling

Build a `MarkdownTheme` with a result-builder DSL, then apply it with `.markdownTheme`:

```swift
import EnrichedMarkdown
import SwiftUI

let AppMarkdownTheme = MarkdownTheme {
  Paragraph()
    .font(.body)
    .foregroundStyle(Color(red: 31 / 255, green: 41 / 255, blue: 55 / 255))
    .lineHeight(26)
    .marginBottom(16)

  Heading(1)
    .font(.largeTitle)
    .bold()
    .foregroundStyle(Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255))

  Link()
    .foregroundStyle(Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255))
    .underline()

  CodeBlock()
    .font(.system(.body, design: .monospaced))
    .foregroundStyle(Color(red: 243 / 255, green: 244 / 255, blue: 246 / 255))
    .background(Color(red: 31 / 255, green: 41 / 255, blue: 55 / 255))
    .cornerRadius(8)
    .padding(16)
}

// App-wide / subtree default
HomeScreen()
  .markdownTheme(AppMarkdownTheme)

// Inline builder (same as passing a MarkdownTheme)
EnrichedMarkdownText(content)
  .markdownTheme {
    Link().foregroundStyle(.red)
  }
```

Themes **layer**: each `.markdownTheme` appends on top of parent themes (and `MarkdownTheme.default`). Later layers override only the properties they set.

When styles should react to appearance or Dynamic Type changes, use `rememberMarkdownTheme` after reading those values from the environment:

```swift
struct RootView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    let theme = rememberMarkdownTheme(
      colorScheme: colorScheme,
      dynamicTypeSize: dynamicTypeSize
    ) {
      Paragraph().foregroundStyle(.primary)
      Link().foregroundStyle(.tint)
    }

    Content()
      .markdownTheme(theme)
  }
}
```

Prefer semantic colors (`.primary`, `.secondary`, `.tint`, `.quaternary`) when you want automatic light/dark adaptation; pass a concrete `Color` (or hex) for fixed branding.

### Theme elements

The `MarkdownTheme` builder supports these elements:

| Element | Applies to |
|---------|------------|
| `Paragraph()` | Body text |
| `Heading(1)` … `Heading(6)` | Headings |
| `Link()` | Links |
| `Strong()` | Bold text |
| `Emphasis()` | Italic text |
| `Code()` | Inline code |
| `CodeBlock()` | Fenced code blocks |
| `Blockquote()` | Block quotes |
| `List()` | Ordered and unordered lists |
| `BlockImage()` | Block images |
| `InlineImage()` | Inline images |
| `ThematicBreak()` | Horizontal rules |

Common modifiers (available on most elements): `.font`, `.fontFamily(_:size:)`, `.fontSize`, `.bold`, `.fontDesign`, `.foregroundStyle`, `.marginTop`, `.marginBottom`, `.lineHeight`, `.textAlignment`.

For custom families, `.bold()` picks a bold face from the same `UIFont` family when one is registered (e.g. `Helvetica` → `Helvetica-Bold`). If no bold face exists, the original face is kept. `.fontDesign` only applies to system fonts, not `.fontFamily`.

Element-specific modifiers include:

- **Link:** `.underline(_:)`
- **Code / CodeBlock / Blockquote:** `.background` / `.backgroundStyle`
- **CodeBlock / Blockquote:** `.borderColor`, `.borderWidth`, `.padding` / `.gapWidth`, `.cornerRadius` / `.borderRadius`
- **List:** `.bulletColor`, `.markerColor`, `.bulletSize`, `.markerMinWidth`, `.gapWidth`, `.marginLeft`
- **BlockImage:** `.height`, `.borderRadius`
- **InlineImage:** `.size`
- **ThematicBreak:** `.color` / `.foregroundStyle`, `.height`

## API reference

### `EnrichedMarkdownText`

```swift
public struct EnrichedMarkdownText: View {
  public init(_ markdown: String)
}
```

| Parameter | Description |
|-----------|-------------|
| `markdown` | Markdown source string |

Style and link handling come from the environment (`.markdownTheme`, `.onLinkPress`), not from initializer parameters.

### `.markdownTheme`

```swift
extension View {
  func markdownTheme(_ theme: MarkdownTheme) -> some View
  func markdownTheme(@MarkdownThemeBuilder _ content: () -> MarkdownThemeGroup) -> some View
}
```

Provides a `MarkdownTheme` for a subtree. Nested themes layer on top of parents.

### `MarkdownTheme`

```swift
public struct MarkdownTheme: Sendable {
  public init(@MarkdownThemeBuilder _ content: () -> MarkdownThemeGroup)
  public static let `default`: MarkdownTheme
}
```

### `.onLinkPress`

```swift
extension View {
  func onLinkPress(_ action: @escaping (URL) -> Void) -> some View
}
```

Called when a link inside `EnrichedMarkdownText` is tapped. Scope it to a single view or a larger subtree.

### `rememberMarkdownTheme`

```swift
@MainActor
public func rememberMarkdownTheme(
  colorScheme: ColorScheme,
  dynamicTypeSize: DynamicTypeSize,
  @MarkdownThemeBuilder _ content: () -> MarkdownThemeGroup
) -> MarkdownTheme
```

Re-creates a theme when `colorScheme` or `dynamicTypeSize` changes. Call from `View.body` after reading those environment values.

## Supported Markdown

- Headings (`#`–`######`)
- Paragraphs, line breaks
- **Bold**, *italic*, `inline code`
- Fenced code blocks
- Block quotes
- Ordered and unordered lists
- Links and images (block and inline)
- Thematic breaks (`---`)

## Development

```sh
yarn workspace @enriched-markdown/ios build
yarn workspace @enriched-markdown/ios test
yarn workspace @enriched-markdown/ios clean
```

These scripts run `swift build` / `swift test` / `swift package clean` from the repository root.
