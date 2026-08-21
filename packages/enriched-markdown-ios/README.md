<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/user-attachments/assets/734bd3a3-aed1-4c33-836e-4e26e48afd19">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/user-attachments/assets/a6fee18f-fb50-422e-83e6-73e18ea79b2a">
  <img alt="Enriched Markdown by Software Mansion" src="https://github.com/user-attachments/assets/734bd3a3-aed1-4c33-836e-4e26e48afd19">
</picture>

# Enriched Markdown iOS

Standalone SwiftUI library for rendering enriched Markdown on iOS. This package is separate from the React Native npm package and is distributed as a Swift Package (`EnrichedMarkdown`).

## Installation

Add the package via [Swift Package Manager](https://www.swift.org/documentation/package-manager/). The `Package.swift` lives at the repository root.

**Xcode:** File → Add Package Dependencies… → enter `https://github.com/software-mansion-labs/enriched-markdown-ios`, then select the `EnrichedMarkdown` product.

**Package.swift:**

```swift
dependencies: [
  .package(
    url: "https://github.com/software-mansion-labs/enriched-markdown-ios.git",
    from: "0.1.0"
  ),
],
targets: [
  .target(
    name: "YourApp",
    dependencies: [
      .product(name: "EnrichedMarkdown", package: "enriched-markdown-ios"),
    ]
  ),
]
```

For local development, add a path dependency to a local checkout instead:

```swift
.package(path: "../enriched-markdown-ios")
```

Requirements: **iOS 16+**, SwiftUI.

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

See the full example in [`apps/ios-example`](https://github.com/software-mansion/enriched-markdown/tree/main/apps/ios-example).

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
| `Strikethrough()` | Struck-through text |
| `Underline()` | Underlined text (`Md4cFlags(underline: true)`) |
| `Code()` | Inline code |
| `CodeBlock()` | Fenced code blocks |
| `Blockquote()` | Block quotes |
| `List()` | Ordered and unordered lists |
| `TaskList()` | Task-list checkboxes (`- [x]`) |
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
- **TaskList:** `.checkedColor`, `.borderColor`, `.checkmarkColor`, `.checkboxSize`, `.checkboxBorderRadius`, `.checkedTextColor`, `.checkedStrikethrough`
- **BlockImage:** `.height`, `.borderRadius`
- **InlineImage:** `.size`
- **ThematicBreak:** `.color` / `.foregroundStyle`, `.height`

## API reference

### `EnrichedMarkdownText`

```swift
public struct EnrichedMarkdownText: View {
  public init(_ markdown: String, flags: Md4cFlags = .commonMark)
}
```

| Parameter | Description |
|-----------|-------------|
| `markdown` | Markdown source string |
| `flags` | Optional parser extensions (see `Md4cFlags`) |

Style and interaction handling come from the environment (`.markdownTheme`, `.onLinkPress`, and the other modifiers below), not from initializer parameters.

### `Md4cFlags`

```swift
public struct Md4cFlags: Equatable, Sendable {
  public var underline: Bool            // __text__ renders underlined instead of bold
  public var hardSoftBreaks: Bool       // single newlines become visible line breaks
  public var permissiveAutolinks: Bool  // bare URLs become links (default true)
  public var latexMath: Bool
  public var superscript: Bool
  public var subscript: Bool
  public var highlight: Bool

  public static let commonMark: Md4cFlags
}
```

`underline`, `hardSoftBreaks`, and `permissiveAutolinks` affect rendering. The remaining flags gate parsing only — their content currently renders as plain text.

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

### `.onLinkPress` / `.onLinkLongPress`

```swift
extension View {
  func onLinkPress(_ action: @escaping (URL) -> Void) -> some View
  func onLinkLongPress(_ action: @escaping (URL) -> Void) -> some View
}
```

`onLinkPress` is called when a link is tapped. `onLinkLongPress` is called when a link is long-pressed, replacing the system link menu; without it, a long-press behaves like a press when `onLinkPress` is set. Scope either to a single view or a larger subtree.

### `.markdownSelectable` / `.markdownSelectionColor`

```swift
extension View {
  func markdownSelectable(_ isSelectable: Bool) -> some View   // default true
  func markdownSelectionColor(_ color: Color?) -> some View    // default nil = system tint
}
```

`markdownSelectable(false)` disables text selection while links stay tappable. `markdownSelectionColor` tints the selection highlight, handles, and caret (UIKit derives all three from one tint).

### `.markdownSelectionMenu`

```swift
public struct MarkdownSelectionMenuConfig: Equatable, Sendable {
  public init(
    copyAsMarkdown: Bool = true,
    copyImageUrl: Bool = true,
    copyAsMarkdownLabel: String = "Copy as Markdown"
  )
}

extension View {
  func markdownSelectionMenu(_ config: MarkdownSelectionMenuConfig) -> some View
}
```

Configures the custom items added to the text-selection edit menu:

- **Copy as Markdown** puts the selection on the clipboard as markdown. A selection covering the whole document returns the original source verbatim; partial selections are reconstructed from the rendered text.
- **Copy Image URL** / **Copy N Image URLs** appears when the selection contains images with http(s) URLs.
- **Select All** is provided when the system omits it for non-editable text views.

### `.markdownImageRequestHeaders`

```swift
extension View {
  func markdownImageRequestHeaders(_ headers: [String: String]) -> some View
}
```

Custom HTTP headers sent with every markdown image request, e.g. for authenticated CDNs. The same URL fetched with different headers is cached separately.

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

## Copy & clipboard

System **Copy** puts two flavors of the selection on the pasteboard: plain text and styled HTML (`public.html`), so pasting into rich-text targets keeps headings, inline styles, lists, blockquotes, code blocks, links, and images. Plain-text targets receive plain text as usual.

The selection menu additionally offers **Copy as Markdown** and **Copy Image URL(s)** — see `.markdownSelectionMenu` above.

## Image sources

Images load from these sources:

| Source | Example |
|--------|---------|
| `http(s)://` | `![alt](https://example.com/pic.png)` — with `.markdownImageRequestHeaders` applied |
| `file://` | `![alt](file:///path/to/pic.png)` — percent-encoded paths supported |
| Absolute path | `![alt](/path/to/pic.png)` |
| `data:` | `![alt](data:image/png;base64,…)` |
| Bundle resource name | `![alt](logo.png)` — looked up in `Bundle.main` (loose files and asset catalogs), with a normalized fallback (lowercase, `-` → `_`) |

All decodes are downsampled to the screen's pixel width, so large images never decode at full size. Downloads are cached (memory + disk) and deduplicated in flight.

## Accessibility

VoiceOver walks the rendered markdown as individual elements rather than one text blob:

- Headings announce "heading, level N"
- Links are activatable elements that invoke `.onLinkPress`
- Images read their alt text ("Image" when absent)
- List items announce their position ("bullet point", "list item N", with a "nested" prefix)

Dynamic Type is supported throughout via text styles in the default theme.

## Supported Markdown

- Headings (`#`–`######`)
- Paragraphs, line breaks
- **Bold**, *italic*, `inline code`
- ~~Strikethrough~~ (`~~text~~`)
- Underline (`__text__` with `Md4cFlags(underline: true)`)
- Fenced code blocks
- Block quotes
- Ordered and unordered lists
- Task lists (`- [x]` / `- [ ]`, display-only checkboxes)
- Links and images (block and inline)
- Autolinked bare URLs, `www.` links, and emails (`permissiveAutolinks`, on by default)
- Thematic breaks (`---`)

## Development

```sh
yarn workspace @enriched-markdown/ios build
yarn workspace @enriched-markdown/ios test
yarn workspace @enriched-markdown/ios clean
```

These scripts run `swift build` / `swift test` / `swift package clean` from the package root.

In the monorepo, `core/md4c` and `core/parser` are symlinks into the shared C++ sources at `packages/core/cpp`. When syncing this folder to the standalone repository, dereference them so real files are copied (e.g. `rsync -a --copy-links`).
