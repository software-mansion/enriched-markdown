---
sidebar_label: UIKit interop
sidebar_position: 5
---

# UIKit interop

The package's public surface is SwiftUI: `EnrichedMarkdownText` is a `View`, and everything else configures it through the environment. The UIKit text view underneath is an implementation detail and is not exported.

That leaves two ways into a UIKit codebase, and only one of them gives you the whole renderer.

## Hosting the view

`UIHostingController` is the supported route, and it keeps every feature - link handling, task toggles, spoilers, the selection menu, the accessibility tree:

```swift
import EnrichedMarkdown
import SwiftUI
import UIKit

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
- **`EnrichedMarkdownText` sizes itself to its content** - its height is the document's height, with no internal scrolling. Inside a `ScrollView` as above, that is exactly what you want. If you instead need the hosting view to report the document's height to a UIKit layout - a cell, a stack view - set `host.sizingOptions = .intrinsicContentSize` so it publishes an intrinsic content size, and let your own scroll view do the scrolling.

To put one in a `UITableViewCell` or `UICollectionViewCell`, host it as a child controller of the view controller that owns the collection, the way you would any other SwiftUI-in-a-cell.

## Rendering to an `NSAttributedString`

[`MarkdownRenderer.render`](/ios/api-reference/markdown-theme#markdownrenderer) turns a document into an `NSAttributedString` with no view involved:

```swift
let text = MarkdownRenderer.render(markdown, config: .baseline())
label.attributedText = text
```

This is genuinely useful for tests, for a one-line label, or for measuring text. It is **not** a way to render the library in a `UITextView`, because a large part of the rendering is not in the string.

### What is in the string

Fonts, colors, and inline backgrounds; paragraph styles, indents, and block margins; links as `.link` attributes; and everything implemented as a text attachment - images, thematic breaks, tables, and typeset math. The table and math attachments register their view providers globally, so a TextKit 2 text view will even lay those out and scroll them.

### What is not

Everything the view draws **around** the text, and everything the view handles:

| Missing | Why |
| --- | --- |
| List bullets and numbers | Drawn in the text view's margins, not stored as glyphs |
| Task list checkboxes | Same, and their taps are the view's |
| Blockquote and admonition bars and fills | Drawn behind the text |
| Code block fills and borders | Drawn behind the text |
| Spoiler overlays | Overlay views managed by the text view |
| Link taps, task toggles, spoiler reveals | Gesture handling lives in the view |
| Copy as Markdown, Copy Image URL, the HTML pasteboard flavor | Edit-menu and pasteboard overrides on the view |
| The VoiceOver element tree and rotors | Built by the view from the layout |

A document of headings, paragraphs, inline styles, links, and images survives the trip well. One with lists, quotes, callouts, code blocks, or spoilers comes out as **unmarked indented text** - the content is all there, the structure is not.

:::caution
If you are reaching for `render` because a `UITextView` seems simpler than hosting SwiftUI, expect to reimplement the decoration and interaction layers yourself. Hosting the view is almost always the shorter path.
:::

## Using the parser directly

`Parser` is public and returns the AST, which is the right tool when you want to inspect a document rather than display it - counting headings, extracting the first image, validating links in a test:

```swift
import EnrichedMarkdown

let ast = Parser.shared.parseMarkdown("# Title\n\n![hero](hero.png)", flags: .commonMark)

func imageURLs(in node: MarkdownASTNode) -> [String] {
  let own = node.type == .image ? [node.attribute("url")].compactMap { $0 } : []
  return own + node.children.flatMap(imageURLs)
}
```

`MarkdownASTNode` gives you `type`, `content`, `attributes` (through `attribute(_:)`), and `children`. Parsing is pure and has no UIKit dependency of its own - though the package as a whole is iOS-only, so this still runs on a simulator or device rather than in a macOS unit test process.

## See also

- [`MarkdownTheme`](/ios/api-reference/markdown-theme#markdownrenderer) - `MarkdownRenderer` and `MarkdownStyleConfig`.
- [`EnrichedMarkdownText`](/ios/api-reference/enriched-markdown-text) - the modifiers you apply to `rootView`.
