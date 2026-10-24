---
sidebar_label: UIKit interop
sidebar_position: 5
---

# UIKit interop

The package's public surface is SwiftUI: `EnrichedMarkdownText` is a `View`, and everything else configures it through the environment. The UIKit text view underneath is an implementation detail and is not exported.

That leaves two ways into a UIKit codebase, and only one of them gives you the whole renderer.

## Hosting the view {#hosting}

`UIHostingController` is the supported route, and it keeps every feature - link handling, task toggles, spoilers, the selection menu, the accessibility tree:

```swift
import EnrichedMarkdown
import SwiftUI
import UIKit

let appTheme = MarkdownTheme {
  Paragraph().lineHeight(26).marginBottom(16)
  Link().foregroundStyle(.tint)
}

final class ArticleViewController: UIViewController {
  private let markdown: String

  init(markdown: String) {
    self.markdown = markdown
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()

    let root = ScrollView {
      EnrichedMarkdownText(markdown)
        .padding()
    }
    .markdownTheme(appTheme)

    let host = UIHostingController(rootView: root)
    addChild(host)
    host.view.frame = view.bounds
    host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(host.view)
    host.didMove(toParent: self)
  }
}
```

Two things to get right:

- **Apply the modifiers inside the SwiftUI hierarchy**, on `rootView`, not on the hosting controller's `view`. They are environment values, and a `UIView` has no way to set one. The same goes for link routing: install an `OpenURLAction` with `.environment(\.openURL, …)` on `rootView` rather than reaching for a UIKit delegate.
- **`EnrichedMarkdownText` sizes itself to its content** - its height is the document's height, with no internal scrolling. Inside a `ScrollView` as above, that is exactly what you want.

### Sizing inside a UIKit layout {#sizing}

If you need the hosting view to report the document's height to a UIKit layout - a stack view, say - set `host.sizingOptions = .intrinsicContentSize` so it publishes an intrinsic content size, and let your own scroll view do the scrolling. Two caveats:

- **The height is measured at the width SwiftUI proposes.** An intrinsic-size query proposes no width, and the view then measures itself at the full screen width. Constrain the hosting view's width (pin its leading and trailing edges) so the height matches the width it is actually laid out at.
- **The height grows after the first layout.** The document renders off the main thread, so the first pass measures an empty view; the height updates when the render lands, and again when a remote image settles its size. Do not cache the first height you see.

### In table and collection view cells {#cells}

On iOS 16 and later - the package's minimum - use `UIHostingConfiguration`. It hosts the view in the cell without a child view controller and lets self-sizing cells pick up the height, including the late updates above:

```swift
import EnrichedMarkdown
import SwiftUI
import UIKit

func configure(_ cell: UICollectionViewListCell, with markdown: String, theme: MarkdownTheme) {
  cell.contentConfiguration = UIHostingConfiguration {
    EnrichedMarkdownText(markdown)
      .markdownTheme(theme)
  }
}
```

## Rendering to an `NSAttributedString` {#rendering}

[`MarkdownRenderer.render`](/ios/api-reference/markdown-theme#markdownrenderer) turns a document into an `NSAttributedString` with no view involved:

```swift
public static func render(
  _ markdown: String,
  config: MarkdownStyleConfiguration,
  options: MarkdownParsingOptions = .commonMark,
  imageRequestHeaders: [String: String] = [:],
  writingDirection: MarkdownWritingDirection = .firstStrong,
  layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight,
  codeBlockLayout: MarkdownCodeBlockLayout = .wrapping
) -> NSAttributedString
```

Resolve `config` from the same theme your SwiftUI screens use, against the view's trait collection, and pass the view's layout direction - the view does both for you, `render` does neither:

```swift
import EnrichedMarkdown
import SwiftUI
import UIKit

let appTheme = MarkdownTheme {
  Paragraph().font(.subheadline)
  Strong().foregroundStyle(.tint)
}

final class NoticeViewController: UIViewController {
  private let label = UILabel()

  override func viewDidLoad() {
    super.viewDidLoad()
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(label)
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
      label.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
      label.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
    ])

    let config = MarkdownStyleConfiguration.resolve(
      layers: [.default, appTheme],
      traitCollection: traitCollection
    )
    label.attributedText = MarkdownRenderer.render(
      "**Heads up:** sync is paused until you sign in again.",
      config: config,
      layoutDirection: view.effectiveUserInterfaceLayoutDirection
    )
  }
}
```

The config is resolved once, so it does not follow later appearance or text-size changes by itself: render again when the trait collection changes if your label has to track them.

This is genuinely useful for tests, for a short label, or for measuring text. It is **not** a way to render the library in a `UITextView`, because a large part of the rendering is not in the string.

### What is in the string

Fonts, colors, and inline backgrounds; paragraph styles, indents, and block margins; links as `.link` attributes; and everything implemented as a text attachment - images, thematic breaks, tables, and, with `codeBlockLayout: .scrollable`, code blocks. The table and scrollable code block attachments register their view providers globally, so a TextKit 2 text view (`UITextView(usingTextLayoutManager: true)`) will even lay those out and scroll them.

Images need a TextKit 2 text view as well. They start as grey placeholders and are swapped in when the download finishes, and that refresh goes through the text view's TextKit 2 layout manager. In a `UILabel`, or a TextKit 1 text view, an image stays a placeholder for good - which is why the example above uses an image-free document.

The string ends at its last visible character, so a `UITextView` of your own gets the content height and nothing below it: neither the last block's bottom margin nor the bottom padding of a code block that ends the document. `EnrichedMarkdownText` lays both out below the text, the margin only with [`.markdownBottomMargin(.visible)`](/ios/api-reference/enriched-markdown-text#markdownbottommargin).

### Math and syntax highlighting {#optional-products}

Plain `render` runs none of the optional products, even when they are linked: `$…$` math stays as its source text, and code blocks are not colored. Each product adds its own counterpart, and each needs its default theme among the layers you resolve - the view inserts those for you, `resolve(layers:)` does not:

```swift
import EnrichedMarkdown
import EnrichedMarkdownLaTeX
import EnrichedMarkdownSyntaxHighlighting
import UIKit

func renderWithMath(_ markdown: String, theme: MarkdownTheme, traits: UITraitCollection) -> NSAttributedString {
  MarkdownRenderer.renderLaTeX(
    markdown,
    config: .resolve(layers: [.default, .latexDefault, theme], traitCollection: traits)
  )
}

func renderWithColoredCode(_ markdown: String, theme: MarkdownTheme, traits: UITraitCollection) -> NSAttributedString {
  MarkdownRenderer.renderSyntaxHighlighted(
    markdown,
    config: .resolve(layers: [.default, .syntaxHighlightingDefault, theme], traitCollection: traits)
  )
}
```

The two cannot be combined in one call. See [LaTeX math](/ios/guides/latex-math#rendering-without-a-view) and [Syntax highlighting](/ios/guides/syntax-highlighting) for their parameters.

### What is not

Everything the view draws **around** the text, and everything the view handles:

| Missing | Why |
| --- | --- |
| List bullets and numbers | Drawn in the text view's margins, not stored as glyphs |
| Task list checkboxes | Same, and their taps are the view's |
| Admonition icons | Drawn at the start of the title line, like list markers |
| Blockquote and admonition bars and fills | Drawn behind the text |
| Code block fills and borders | Drawn behind the text |
| Spoiler overlays | Overlay views managed by the text view |
| Link taps, task toggles, spoiler reveals | Gesture handling lives in the view |
| Copy as Markdown, Copy Image URL, the HTML pasteboard flavor | Edit-menu and pasteboard overrides on the view |
| The VoiceOver element tree and rotors | Built by the view from the layout |

A document of headings, paragraphs, inline styles, and links survives the trip well. One with lists, quotes, callouts, or wrapping code blocks comes out as **unmarked indented text** - the content is all there, the structure is not.

Spoilers are the exception: their content is **not** all there. Spoiler text is rendered with a transparent color and its links are removed, so without the view's overlay and tap-to-reveal it shows up as a blank gap that nothing can reveal.

:::caution
If you are reaching for `render` because a `UITextView` seems simpler than hosting SwiftUI, expect to reimplement the decoration and interaction layers yourself. Hosting the view is almost always the shorter path.
:::

## Using the parser directly {#parser}

`Parser` is public and returns the AST, which is the right tool when you want to inspect a document rather than display it - counting headings, extracting the first image, validating links in a test:

```swift
import EnrichedMarkdown

let ast = Parser.shared.parseMarkdown("# Title\n\n![hero](hero.png)", options: .commonMark)

let heroURL = ast.first(ofType: .image)?.attribute("url")
let imageURLs = ast.all(ofType: .image).compactMap { $0.attribute("url") }
```

`MarkdownASTNode` gives you `type`, `content`, `attributes` (through `attribute(_:)`), and `children`, plus three traversal helpers:

- **`first(ofType:)`** - the first node of that type in document order, the node itself included.
- **`all(ofType:)`** - every node of that type in the subtree, in document order.
- **`child(ofType:)`** - the first **direct** child of that type, without descending further.

Parsing is pure and has no UIKit dependency of its own - though the package as a whole is iOS-only, so this still runs on a simulator or device rather than in a macOS unit test process.

## See also

- [`MarkdownTheme`](/ios/api-reference/markdown-theme#markdownrenderer) - `MarkdownRenderer` and `MarkdownStyleConfiguration`.
- [`EnrichedMarkdownText`](/ios/api-reference/enriched-markdown-text) - the modifiers you apply to `rootView`.
