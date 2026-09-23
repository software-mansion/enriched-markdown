<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/user-attachments/assets/734bd3a3-aed1-4c33-836e-4e26e48afd19">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/user-attachments/assets/a6fee18f-fb50-422e-83e6-73e18ea79b2a">
  <img alt="Enriched Markdown by Software Mansion" src="https://github.com/user-attachments/assets/734bd3a3-aed1-4c33-836e-4e26e48afd19">
</picture>

# Enriched Markdown iOS

Standalone SwiftUI library for rendering enriched Markdown on iOS. This package is separate from the React Native npm package and is distributed as a Swift Package with two products: `EnrichedMarkdown`, and the optional `EnrichedMarkdownLaTeX` for math rendering.

## Installation

Add the package via [Swift Package Manager](https://docs.swift.org/latest/documentation/packagemanagerdocs/). The `Package.swift` lives at the repository root.

**Xcode:** File → Add Package Dependencies… → enter `https://github.com/software-mansion-labs/enriched-markdown-ios`, then select the `EnrichedMarkdown` product (and the optional `EnrichedMarkdownLaTeX` for math, see [LaTeX math](#latex-math)).

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

`EnrichedMarkdown` is all most apps need. Math rendering ships as a separate,
optional product: leave it out and nothing links the typesetting engine
(~3–5 MB of app size), with `$…$` staying plain text. Apps that show formulas
add `EnrichedMarkdownLaTeX` alongside it:

```swift
.target(
  name: "YourApp",
  dependencies: [
    .product(name: "EnrichedMarkdown", package: "enriched-markdown-ios"),
    .product(name: "EnrichedMarkdownLaTeX", package: "enriched-markdown-ios"),
  ]
),
```

Math is then enabled per view with `.markdownLaTeX()` — see [LaTeX math](#latex-math).

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
      .environment(\.openURL, OpenURLAction { url in
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

Themes built in `body` follow appearance and Dynamic Type changes on their own, because SwiftUI re-evaluates `body` when those environment values change:

```swift
struct RootView: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Content()
      .markdownTheme {
        Paragraph().foregroundStyle(.primary)
        Link().foregroundStyle(colorScheme == .dark ? .tint : .secondary)
      }
  }
}
```

Prefer semantic colors (`.primary`, `.secondary`, `.tertiary`, `.quaternary`, `.tint`) when you want automatic light/dark adaptation; pass a concrete `Color` (or hex) for fixed branding.

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
| `Underline()` | Underlined text (`MarkdownParsingOptions(underline: true)`) |
| `Superscript()` | Superscript text (`MarkdownParsingOptions(superscript: true)`) |
| `Subscript()` | Subscript text (`MarkdownParsingOptions(subscript: true)`) |
| `Highlight()` | Highlighted text (`MarkdownParsingOptions(highlight: true)`) |
| `Spoiler()` | The overlay concealing `\|\|spoiler\|\|` text until tapped |
| `Code()` | Inline code |
| `CodeBlock()` | Fenced code blocks |
| `Blockquote()` | Block quotes |
| `Admonition(.note)` | GitHub alerts (`> [!NOTE]`, `MarkdownParsingOptions(admonitions: true)`), one element per type |
| `List()` | Ordered and unordered lists |
| `TaskList()` | Task-list checkboxes (`- [x]`) |
| `Table()` | GFM tables |
| `BlockImage()` | Block images |
| `InlineImage()` | Inline images |
| `ThematicBreak()` | Horizontal rules |
| `MathBlock()` | Root-level `$$…$$` display math (`EnrichedMarkdownLaTeX`, see [LaTeX math](#latex-math)) |
| `InlineMath()` | `$…$` math in running text (`EnrichedMarkdownLaTeX`) |

Common modifiers (available on most elements): `.font`, `.font(size:weight:design:)`, `.font(custom:size:)`, `.fontWeight`, `.bold`, `.italic`, `.fontDesign`, `.foregroundStyle`, `.marginTop`, `.marginBottom`, `.lineHeight`, `.multilineTextAlignment`.

`.font` takes the SwiftUI text styles in every spelling — `.body`, `.system(.title)`, `.system(.title, design: .serif, weight: .bold)` — and they track Dynamic Type. A point-sized or custom `Font` (`.system(size:)`, `.custom(_:size:)`, `.weight()`, `.italic()`) cannot be read back through public API, so it logs a runtime warning and renders as `.body`; use `.font(size:weight:design:)` and `.font(custom:size:)` for those. `.fontWeight`, `.bold()`, `.italic()`, and `.fontDesign` layer over whatever font the lower theme set, so `Heading(1).bold()` alone bolds the default heading. `marginTop` / `marginBottom` are outer spacing between blocks and do not collapse the way CSS margins do.

For custom families, `.bold()` and `.italic()` pick the matching face from the same `UIFont` family when one is registered (e.g. `Helvetica` → `Helvetica-Bold`); italic is synthesized when no face exists, bold falls back to the original face. `.fontDesign` only applies to system fonts, not `.font(custom:size:)`.

Element-specific modifiers include:

- **Link:** `.underline(_:)`
- **Code / CodeBlock / Blockquote / Highlight:** `.background` / `.backgroundStyle`
- **CodeBlock / Blockquote / Table:** `.border(_:width:)` — color and width together, as SwiftUI's modifier; leave `width` out to recolor a border a lower layer sized, or use `.border(width:)` to resize one a lower layer colored
- **CodeBlock / Blockquote:** `.padding` / `.gapWidth`, `.cornerRadius` (CodeBlock)
- **Admonition:** `.foregroundStyle` (the accent bar, icon, and title tint) and `.background` / `.backgroundStyle` — the only modifiers; font, spacing, and geometry follow `Blockquote`. Types: `.note`, `.tip`, `.important`, `.warning`, `.caution`; the defaults are GitHub's palette with no fill
- **List:** `.bulletColor`, `.markerColor`, `.bulletSize`, `.markerMinWidth`, `.gapWidth`, `.marginLeading`
- **TaskList:** `.checkedColor`, `.borderColor`, `.checkmarkColor`, `.checkboxSize`, `.checkboxCornerRadius`, `.checkedTextColor`, `.checkedStrikethrough`
- **Spoiler:** `.foregroundStyle` (the particles or the solid box) and `.background` (backdrop under the particles, default system background) — the only modifiers; the text keeps the surrounding font and color once revealed. Particle density and speed and the solid box's corner radius belong to the overlay choice: `.markdownSpoilerOverlay(.particles(density: 12, speed: 30))`
- **Superscript / Subscript:** `.fontScale` (default `0.75`), `.baselineOffsetScale` (shift up/down, defaults `0.35` / `0.20`) — both fractions of the surrounding text size, and the only modifiers; font and color follow the surrounding text
- **Table:** `.headerFont` (a text style or `custom:size:`), `.headerForegroundStyle`, `.headerBackground`, `.rowEvenBackground`, `.rowOddBackground`, `.border(_:width:)`, `.cornerRadius`, `.cellPadding(horizontal:vertical:)`, `.alignment` (`HorizontalAlignment`: `.leading`, `.center`, `.trailing`)
- **BlockImage:** `.height`, `.maxHeight`, `.aspectRatio`, `.contentMode`, `.cornerRadius` — see [Image sizing](#image-sizing)
- **InlineImage:** `.size`
- **ThematicBreak:** `.foregroundStyle`, `.height`
- **MathBlock:** `.font(size:)`, `.foregroundStyle`, `.background` / `.backgroundStyle`, `.padding`, `.marginTop`, `.marginBottom`, `.multilineTextAlignment` — the only modifiers; the face is always KaTeX's
- **InlineMath:** `.foregroundStyle` — the only modifier; size follows the surrounding text

## API reference

### `EnrichedMarkdownText`

```swift
public struct EnrichedMarkdownText: View {
  public init(_ markdown: String, options: MarkdownParsingOptions = .commonMark)
}
```

| Parameter | Description |
|-----------|-------------|
| `markdown` | Markdown source string |
| `options` | Optional parser extensions (see `MarkdownParsingOptions`) |

Style and interaction handling come from the environment (`.markdownTheme`, `openURL`, and the other modifiers below), not from initializer parameters.

### `MarkdownParsingOptions`

```swift
public struct MarkdownParsingOptions: Equatable, Sendable {
  public var underline: Bool            // __text__ renders underlined instead of bold
  public var hardSoftBreaks: Bool       // single newlines become visible line breaks
  public var preserveBlankLines: Bool   // consecutive blank lines render as extra empty lines
  public var permissiveAutolinks: Bool  // bare URLs become links (default true)
  public var superscript: Bool          // ^text^ renders as superscript
  public var subscript: Bool            // ~text~ renders as subscript
  public var highlight: Bool            // ==text== renders with a background
  public var admonitions: Bool          // > [!NOTE] quotes render as GitHub alerts

  public static let commonMark: MarkdownParsingOptions
}
```

`underline`, `hardSoftBreaks`, `preserveBlankLines`, `permissiveAutolinks`, `superscript`, `subscript`, `highlight`, and `admonitions` affect rendering. Tables, task lists, strikethrough, and spoilers are always enabled and need no options.

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

### Links: `openURL` / `.onMarkdownLinkLongPress`

```swift
extension View {
  func onMarkdownLinkLongPress(_ action: @escaping (URL) -> Void) -> some View
}
```

A tapped link calls the SwiftUI `openURL` environment action, exactly as `Text` does with its own markdown links. Left alone it opens the URL with the system; install an `OpenURLAction` to route it yourself, and return `.systemAction` to fall through:

```swift
EnrichedMarkdownText(markdown)
  .environment(\.openURL, OpenURLAction { url in
    guard url.host == "myapp.example" else { return .systemAction }
    navigate(to: url)
    return .handled
  })
```

`onMarkdownLinkLongPress` is called when a link is long-pressed, replacing the system link menu. Without it the system menu stays. Scope either to a single view or a larger subtree.

### `.onTaskListItemToggle` / `.markdownTaskListItemToggleEnabled`

```swift
public struct TaskListItemToggle: Equatable, Sendable {
  public let index: Int        // 0-based, in document order
  public let isChecked: Bool   // state after the toggle
  public let text: String      // first line of the item's plain text
}

extension View {
  func onTaskListItemToggle(_ action: @escaping (TaskListItemToggle) -> Void) -> some View
  func markdownTaskListItemToggleEnabled(_ enabled: Bool) -> some View   // default true
}
```

Tapping a task-list checkbox toggles its checked state in place (including the checked-item text decoration) and calls `onTaskListItemToggle` with the new state. The toggle is visual — the view never mutates your `markdown` string, so persist the change from the handler if you need it back. `markdownTaskListItemToggleEnabled(false)` makes checkbox taps fully inert: no visual toggle and no `onTaskListItemToggle`. Text selection and links are unaffected either way.

### `.markdownSpoilerOverlay`

```swift
extension View {
  func markdownSpoilerOverlay(_ provider: any SpoilerOverlayProvider) -> some View
}

// Built-in overlays, plain or tuned:
.particles                              // the default: 8 particles per 100×100 pt, drifting 20 pt/s
.particles(density: 12, speed: 30)
.solid                                  // a box with 4 pt corners
.solid(cornerRadius: 6)
```

`||spoiler||` text renders transparent under an overlay and shows on tap, one spoiler at a time. A link inside a concealed spoiler is not a link until the spoiler is revealed: no tap, long press, menu, or VoiceOver link element. Revealed spoilers stay revealed across theme changes and conceal again when the `markdown` string changes; Copy as Markdown emits the `||` markers either way. Colors and sizing of the built-in overlays come from the `Spoiler()` theme element; spoiler text reads as ordinary text to VoiceOver, matching the React Native renderer.

#### Custom overlays

Any effect can stand in for the particles: subclass `SpoilerOverlayView` and return it from a `SpoilerOverlayProvider`.

```swift
public protocol SpoilerOverlayProvider: Equatable, Sendable {
  @MainActor
  func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView
}

open class SpoilerOverlayView: UIView {
  public let charRange: NSRange
  public var concealedText: NSAttributedString                // this segment's slice, styled as it reveals
  public init(charRange: NSRange)
  open func animateReveal(completion: @escaping () -> Void)   // default fades alpha; an override calls completion
}
```

```swift
final class BlurOverlayView: SpoilerOverlayView {
  private static let context = CIContext()

  override func layoutSubviews() {
    super.layoutSubviews()
    let text = UIGraphicsImageRenderer(bounds: bounds).image { _ in concealedText.draw(at: .zero) }
    guard let input = CIImage(image: text) else { return }
    layer.contents = Self.context.createCGImage(input.applyingGaussianBlur(sigma: 6), from: input.extent)
  }
}

struct BlurOverlayProvider: SpoilerOverlayProvider {
  func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
    let view = BlurOverlayView(charRange: charRange)
    view.backgroundColor = style.backgroundColor ?? .systemBackground
    return view
  }
}

EnrichedMarkdownText(content)
  .markdownSpoilerOverlay(BlurOverlayProvider())
```

A spoiler gets one view per line segment; the text view sets its frame and recreates it whenever the segment moves, so keep construction cheap. The view must be opaque, because emoji and inline images ignore the transparent foreground under it. An effect that shows the text through draws `concealedText`, the segment's slice with inline styling only, as the blur above does. Overlays are rebuilt when the provider value or the `Spoiler()` style changes, so a provider with parameters should keep them in stored properties and let `Equatable` synthesis compare them.

### `.markdownTextSelection` / `.markdownSelectionColor`

```swift
extension View {
  func markdownTextSelection(_ selectability: some TextSelectability) -> some View   // .enabled (default) / .disabled
  func markdownSelectionColor(_ color: Color?) -> some View                          // default nil = system tint
}
```

`markdownTextSelection(.disabled)` disables text selection while links stay tappable, mirroring SwiftUI's `textSelection`. To drive it from a `Bool`, set the environment value directly: `.environment(\.markdownSelectable, isSelectable)`. `markdownSelectionColor` tints the selection highlight, handles, and caret (UIKit derives all three from one tint).

### `.markdownSelectionMenu`

```swift
public struct MarkdownSelectionMenu: Equatable, Sendable {
  public init(
    copyAsMarkdown: Bool = true,
    copyImageURL: Bool = true,
    copyAsMarkdownLabel: String = "Copy as Markdown"
  )
}

extension View {
  func markdownSelectionMenu(_ menu: MarkdownSelectionMenu) -> some View
}
```

Configures the custom items added to the text-selection edit menu:

- **Copy as Markdown** puts the selection on the clipboard as markdown. A selection covering the whole document returns the original source verbatim; partial selections are reconstructed from the rendered text.
- **Copy Image URL** / **Copy N Image URLs** appears when the selection contains images with http(s) URLs.
- **Select All** is provided when the system omits it for non-editable text views.

### `.markdownAccessibilityLabels`

```swift
public struct MarkdownAccessibilityLabels: Equatable, Sendable {
  public var list: List             // top / nested, each: bulletPoint, orderedItem "List item {n}",
                                    // checkedTask, uncheckedTask
  public var blockquote: Blockquote // quote, nestedQuote
  public var table: Table           // row "Row {n}: {content}"
  public var image: Image           // fallback "Image" (no alt text)
  public var codeBlock: CodeBlock   // copy "Copy code" (custom action name)
  public var rotor: Rotor           // headings, links, images

  public static let `default`: MarkdownAccessibilityLabels
}

extension View {
  func markdownAccessibilityLabels(_ labels: MarkdownAccessibilityLabels) -> some View
}
```

Overrides the strings VoiceOver speaks. Every field defaults to English, so set only what you localize:

```swift
var labels = MarkdownAccessibilityLabels()
labels.list.top.bulletPoint = "Punkt"
labels.list.top.orderedItem = "Listenelement {n}"
labels.rotor.headings = "Überschriften"

EnrichedMarkdownText(markdown)
    .markdownAccessibilityLabels(labels)
```

`{n}` is a 1-based index and `{content}` the comma-joined cell text of a table row; translations must keep the placeholder names. Defaults use the cardinal form ("List item 2") so one template works in every language without plural rules. The math label lives in the LaTeX module: `.markdownLaTeX(accessibilityLabel: "Formel: {speech}")`, or `.markdownLaTeX { latex in … }` for a custom converter.

### `.markdownImageRequestHeaders`

```swift
extension View {
  func markdownImageRequestHeaders(_ headers: [String: String]) -> some View
}
```

Custom HTTP headers sent with every markdown image request, e.g. for authenticated CDNs. The same URL fetched with different headers is cached separately.

### `.markdownWritingDirection`

```swift
extension View {
  func markdownWritingDirection(_ direction: MarkdownWritingDirection) -> some View  // default .firstStrong
}
```

| Value | Behavior |
|-------|----------|
| `.firstStrong` (default) | Each paragraph follows its first strong directional character; paragraphs without one (digits, punctuation) follow the SwiftUI `layoutDirection`. Matches Android and the React Native package. |
| `.natural` | Leaves direction to TextKit, as the React Native prop's `auto` does; list markers, checkboxes, blockquote bars, and paragraphs with no strong character follow the app's interface direction, not the SwiftUI `layoutDirection`, so an `.environment(\.layoutDirection, .rightToLeft)` subtree still gets left-side markers. |
| `.leftToRight` | Forces every paragraph left-to-right. |
| `.rightToLeft` | Forces every paragraph right-to-left. |

Code blocks always render left-to-right. See [Right-to-left text](#right-to-left-text) for what follows a paragraph's direction.

Outside SwiftUI, `MarkdownRenderer.render` and `renderLaTeX` take the same value as `writingDirection:`, plus `layoutDirection: UIUserInterfaceLayoutDirection` (default `.leftToRight`) in place of the SwiftUI `layoutDirection`; pass the hosting view's `effectiveUserInterfaceLayoutDirection`.

### Migrating from 0.1

Every 0.1 name still compiles as a deprecated alias that forwards to its replacement, with an Xcode fix-it where the shape is unchanged. They will be removed in the next major version.

| 0.1 | Now |
|-----|-----|
| `Md4cFlags`, `EnrichedMarkdownText(_:flags:)`, `MarkdownRenderer.render(_:config:flags:)` | `MarkdownParsingOptions`, `options:` |
| `.onLinkPress { url in … }` | `.environment(\.openURL, OpenURLAction { url in …; return .handled })` |
| `.onLinkLongPress` | `.onMarkdownLinkLongPress` |
| `.onTaskListItemPress`, `TaskListItemPressEvent(index:checked:text:)` | `.onTaskListItemToggle`, `TaskListItemToggle(index:isChecked:text:)` |
| `.markdownSelectable(false)` | `.markdownTextSelection(.disabled)` |
| `MarkdownSelectionMenuConfig(copyImageUrl:)` | `MarkdownSelectionMenu(copyImageURL:)` |
| `rememberMarkdownTheme(colorScheme:dynamicTypeSize:) { … }` | `MarkdownTheme { … }` built in `body` |
| `.textAlignment(_:)` (all elements, `MathBlock`) | `.multilineTextAlignment(_:)` |
| `.borderRadius(_:)` on `BlockImage`, `CodeBlock`, `Table` | `.cornerRadius(_:)` |
| `TaskList().checkboxBorderRadius(_:)` | `.checkboxCornerRadius(_:)` |
| `List().marginLeft(_:)` | `.marginLeading(_:)` |
| `Table().align(_: TableAlignment)` | `.alignment(_: HorizontalAlignment)` |
| `ThematicBreak().color(_:)`, `Spoiler().color(_:)` | `.foregroundStyle(_:)` |
| `.borderColor(_:)` + `.borderWidth(_:)` on `CodeBlock`, `Blockquote`, `Table` | `.border(_:width:)` |
| `Table().cellPaddingHorizontal(_:)` / `.cellPaddingVertical(_:)` | `.cellPadding(horizontal:vertical:)` |
| `Spoiler().particleDensity(_:)` / `.particleSpeed(_:)` / `.solidBorderRadius(_:)` | `.markdownSpoilerOverlay(.particles(density:speed:))` / `.markdownSpoilerOverlay(.solid(cornerRadius:))` |
| `SpoilerStyle.solidBorderRadius` | `solidCornerRadius` |
| `MarkdownStyleConfig` | `MarkdownStyleConfiguration` (the `config:` label is unchanged) |
| `.fontSize(_:weight:)`, `.fontFamily(_:size:)` | `.font(size:weight:design:)`, `.font(custom:size:)` |
| `Table().headerFontFamily(_:size:)`, `.headerTextColor(_:)` | `.headerFont(custom:size:)`, `.headerForegroundStyle(_:)` |
| `MathBlock().fontSize(_:)` | `.font(size:)` |
| `EnrichedMarkdown` (an empty namespace enum) | removed; it shadowed the module, so `EnrichedMarkdown.List()` now resolves as module-qualified lookup |
| `CodeBlockStyle.borderRadius`, `ImageStyle.borderRadius`, `TableStyle.borderRadius` / `.align`, `TaskListStyle.checkboxBorderRadius`, `ListStyle.marginLeft` | `cornerRadius`, `alignment`, `checkboxCornerRadius`, `marginLeading` (fields and init labels) |

## Copy & clipboard

System **Copy** puts two flavors of the selection on the pasteboard: plain text and styled HTML (`public.html`), so pasting into rich-text targets keeps headings, inline styles, lists, blockquotes, code blocks, links, and images. Plain-text targets receive plain text as usual.

The selection menu additionally offers **Copy as Markdown** and **Copy Image URL(s)** — see `.markdownSelectionMenu` above.

The HTML flavor carries one `dir` attribute, read from the first copied paragraph (`rtl`, or `auto` under `.markdownWritingDirection(.natural)`); see [Right-to-left text](#right-to-left-text).

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

## Image sizing

Block images fill the width available to them. Three `BlockImage` modifiers decide how tall the box they fill is:

| Modifier | Box height |
|----------|------------|
| `.height(_:)` | Fixed. The default, at 200 points. |
| `.maxHeight(_:)` | The image's own proportions at the current width, capped at this value. |
| `.aspectRatio(_:)` | The width divided by this ratio, e.g. `16 / 9` or `CGSize(width: 16, height: 9)`. |

They are one setting: the last one applied wins, and a theme layered over another replaces its sizing outright.

`.contentMode(_:)` decides how the image fills that box:

| Mode | Drawing | UIKit / SwiftUI | React Native |
|------|---------|-----------------|--------------|
| `.fit` | Scaled to fit inside the box, never cropped | `.scaleAspectFit` / `.fit` | `contain` |
| `.fill` | Scaled to fill the box, cropping what overflows | `.scaleAspectFill` / `.fill` | `cover` |
| `.stretch` | Fills the box exactly, ignoring the image's proportions | `.scaleToFill` | `stretch` |
| `.scaleDown` | Centered at its own size, scaled down only when it exceeds the box | — | `center` |
| `.original` | Centered at its own size, never scaled, cropping what overflows | `.center` | `none` |
| `.fitWidth` | Scaled to the box width and centered vertically, cropping what overflows | — | — |

Left unset it is `.fitWidth` for a `height` box and `.fill` for a `maxHeight` or `aspectRatio` box. `.aspectRatio(_:contentMode:)` sets both at once; note that unlike SwiftUI's modifier of the same name, the ratio shapes the box and the mode places the image inside it.

```swift
EnrichedMarkdownText(markdown)
    .markdownTheme(
        MarkdownTheme {
            BlockImage()
                .maxHeight(320)
                .contentMode(.fit)
        }
    )
```

Three things worth knowing:

- A `maxHeight` box stands at the full cap until the image loads and only then shrinks to the fitted height, so the page reflows once. An `aspectRatio` box is settled from the start and never moves.
- `.cornerRadius` rounds the drawn image, not the box, so with `.fit`, `.scaleDown` or `.original` the corners follow the image.
- `.scaleDown` and `.original` draw the decoded image, and decoding is capped at the screen's pixel width, so a very large image is not drawn at its full pixel size.

Inline images ignore all four modifiers. They are always a square of `InlineImage().size`.

## Accessibility

VoiceOver walks the rendered markdown as individual elements rather than one text blob:

- Headings announce "heading, level N"; a link inside a heading stays its own element and keeps the heading trait
- Links are activatable elements that call the `openURL` action; a linked image (`[![alt](img)](url)`) reads its alt text with both the image and link traits
- Images read their alt text ("Image" when absent)
- List items announce their position ("Bullet point", "List item N", "Task, checked", with "Nested" variants)
- Content inside a blockquote appends "Blockquote" or "Nested blockquote"; an admonition reads its title ("Note", "Tip", …) as its own element first
- Tables read one element per row ("Row N: cell, cell"); the header row carries the heading trait
- Fenced code blocks are one element each, with a "Copy code" custom action (swipe up/down on the element)
- Math from `EnrichedMarkdownLaTeX` reads an English form of the formula ("Math: x squared over 2", "integral from 0 to 1 of …"); `{latex}` in the label template gives the raw source instead, and a closure can plug in another converter
- Rotors (two-finger twist) jump between Headings, Links, and Images

Every spoken string can be localized with `.markdownAccessibilityLabels` (see the API reference); the math label is a parameter of `.markdownLaTeX`, either a template (`"Formel: {speech}"`, `{latex}` for the source) or a `(String) -> String` closure receiving the LaTeX source. The built-in reading (`LaTeXSpeech.spokenForm`) is English and covers fractions, roots, powers and indices, sums/products/integrals/limits with bounds, Greek letters, common relations and functions, decorations, and `\text`; unmapped commands are read by name. Element frames are resolved from the live layout on each query, so they stay correct inside a scrolling container and after Dynamic Type changes.

Dynamic Type is supported throughout via text styles in the default theme.

## Tables

GFM tables render as live views inside the text: columns size to their
content (wrapping long cells), and a table wider than the view scrolls
horizontally in place. Cells support inline styling — bold, italic, code,
strikethrough, and tappable links.

Long-pressing a table offers **Copy** (tab-separated text) and **Copy as
Markdown** (the pipe table rebuilt with alignment separators and inline
markers). Text selection treats a table as a single character; copying a
selection that spans one produces the table as tab-separated text, a
semantic `<table>` in the HTML flavor, and the pipe table in
markdown-based copies. VoiceOver reads one element per row.

Styling comes from the `Table()` theme element (header colors, row
striping, borders, cell padding, alignment); the defaults adapt to light
and dark mode.

## Right-to-left text

Writing direction resolves **per paragraph**: each paragraph takes its base direction from its first strong directional character, so Arabic, Hebrew, or Persian paragraphs right-align inside a left-to-right app and next to English paragraphs in the same document. The block chrome follows the paragraph it belongs to:

| Element | Behavior |
|---------|----------|
| Paragraphs & headings | Base direction from the first strong character, or the direction forced by `.markdownWritingDirection` |
| Lists | Bullet, number, or checkbox drawn on the side matching the item's direction; checkbox taps hit-test on that side |
| Blockquotes & admonitions | Bar drawn on the side matching each quoted paragraph; an admonition's title follows its body |
| Tables | Each cell resolves its own direction from its content |
| Code blocks | Always left-to-right |

Under the default `.firstStrong`, paragraphs with no strong character (digits, punctuation) follow the SwiftUI layout direction, so `.environment(\.layoutDirection, .rightToLeft)` right-aligns neutral content. Copied HTML carries a single `dir` attribute read from the first copied paragraph; receivers apply their own bidi algorithm, so a mixed-direction selection may not reproduce the per-paragraph layout after pasting.

## LaTeX math

Math rendering lives in the optional `EnrichedMarkdownLaTeX` product (see
[Installation](#installation)). Import it and enable math per view:

```swift
import EnrichedMarkdown
import EnrichedMarkdownLaTeX

EnrichedMarkdownText(content)
  .markdownLaTeX()
```

`$…$` typesets inline at the surrounding text size, and a `$$…$$` block on
its own line renders as a full-width panel that scrolls horizontally when
the formula is wider than the line. Source that fails to typeset falls back
to the delimited text. Outside SwiftUI, `MarkdownRenderer.renderLaTeX`
mirrors `MarkdownRenderer.render` with math enabled.

Styling comes from two theme elements the product adds to the builder:

```swift
EnrichedMarkdownText(content)
  .markdownLaTeX()
  .markdownTheme {
    MathBlock()
      .font(size: 22)
      .background(Color(red: 243 / 255, green: 244 / 255, blue: 246 / 255))
      .padding(16)
      .marginBottom(24)
      .multilineTextAlignment(.leading)

    InlineMath()
      .foregroundStyle(.tint)
  }
```

`.markdownLaTeX()` layers `MarkdownTheme.latexDefault` — 20pt formulas
centered on a padded `.quaternary` panel — directly above `MarkdownTheme.default`,
so your own themes still win whether they're applied on an ancestor or on the
view itself. Font size and color left unset follow the paragraph. When
resolving a `MarkdownStyleConfiguration` by hand for `renderLaTeX`, include that
layer: `MarkdownStyleConfiguration.resolve(layers: [.default, .latexDefault, yours], traitCollection: …)`.

## Supported Markdown

- Headings (`#`–`######`)
- Paragraphs, line breaks
- **Bold**, *italic*, `inline code`
- ~~Strikethrough~~ (`~~text~~`)
- Underline (`__text__` with `MarkdownParsingOptions(underline: true)`)
- Superscript (`^text^` with `MarkdownParsingOptions(superscript: true)`)
- Subscript (`~text~` with `MarkdownParsingOptions(subscript: true)`)
- Highlight (`==text==` with `MarkdownParsingOptions(highlight: true)`)
- Spoilers (`||text||`, tap to reveal — see `.markdownSpoilerOverlay`)
- Fenced code blocks
- Block quotes
- GitHub alerts / admonitions (`> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]` with `MarkdownParsingOptions(admonitions: true)`): a tinted bar, icon, and title above the quoted content
- Ordered and unordered lists
- Task lists (`- [x]` / `- [ ]`, tap to toggle — see `.onTaskListItemToggle`)
- Tables (GFM: column alignment, per-cell wrapping, horizontal scrolling)
- Links and images (block and inline)
- Autolinked bare URLs, `www.` links, and emails (`permissiveAutolinks`, on by default)
- Thematic breaks (`---`)
- LaTeX math (`$…$`, `$$…$$`) with the optional `EnrichedMarkdownLaTeX` product — see [LaTeX math](#latex-math)

## Development

```sh
yarn workspace @enriched-markdown/ios build
yarn workspace @enriched-markdown/ios test
yarn workspace @enriched-markdown/ios clean
```

These scripts run `swift build` / `swift test` / `swift package clean` from the package root.

In the monorepo, `core/md4c` and `core/parser` are symlinks into the shared C++ sources at `packages/core/cpp`. When syncing this folder to the standalone repository, dereference them so real files are copied (e.g. `rsync -a --copy-links`).
