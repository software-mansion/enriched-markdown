---
sidebar_label: Installation
sidebar_position: 1
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Installation

`enriched-markdown-ios` is a **standalone Swift package** - a SwiftUI view that renders Markdown as native text. You add it the way you add any other Swift package. The Markdown parser is C and C++ compiled from source into the package; the one prebuilt binary it references is the math engine behind the optional LaTeX product (see [The products](#products)).

:::caution
`enriched-markdown-ios` is **pre-1.0**. Until it reaches a stable release the API can still change between versions: modifiers get renamed, defaults get retuned, and elements can move. On a 0.x version a minor bump can break your build, so depend on `.upToNextMinor(from:)` (or pin an exact version with `.package(url:, exact:)`) rather than a plain `from:`, and check [Breaking changes](/misc/breaking-changes) before upgrading.

These pages are written against the current release and kept in step with it by hand, so one can fall behind the code. If something here does not match what the compiler tells you, that is worth reporting: [open an issue](https://github.com/software-mansion/enriched-markdown/issues) and say which page.
:::

## Requirements

| | |
| --- | --- |
| **Deployment target** | iOS 16.0 |
| **Platforms** | iOS only - iPhone and iPad. Not macOS, watchOS, or tvOS |
| **Swift tools** | 5.9 (Xcode 15 or newer) |
| **UI framework** | SwiftUI - the package exports a `View`, rendered through UIKit underneath |
| **Dependency manager** | Swift Package Manager only - there is no CocoaPods or Carthage distribution |

For the supported versions, see [Compatibility](/misc/compatibility).

## Add the package

<Tabs groupId="spm">
  <TabItem value="xcode" label="Xcode">

**File → Add Package Dependencies…**, enter the repository URL:

```
https://github.com/software-mansion-labs/enriched-markdown-ios
```

set the dependency rule to **Up to Next Minor Version** starting from `0.4.0`, then add the **`EnrichedMarkdown`** product to your app target. Add **`EnrichedMarkdownSyntaxHighlighting`** only if you want code blocks colored, and **`EnrichedMarkdownLaTeX`** only if you render formulas - see [The products](#products).

  </TabItem>
  <TabItem value="manifest" label="Package.swift">

```swift
dependencies: [
  .package(
    url: "https://github.com/software-mansion-labs/enriched-markdown-ios.git",
    .upToNextMinor(from: "0.4.0")
  ),
],
targets: [
  .target(
    name: "YourApp",
    dependencies: [
      .product(name: "EnrichedMarkdown", package: "enriched-markdown-ios"),
      // Optional - add only the ones you use:
      // .product(name: "EnrichedMarkdownSyntaxHighlighting", package: "enriched-markdown-ios"),
      // .product(name: "EnrichedMarkdownLaTeX", package: "enriched-markdown-ios"),
    ]
  ),
]
```

  </TabItem>
</Tabs>

`.upToNextMinor(from: "0.4.0")` accepts 0.4.x patch releases but not 0.5.0, which may contain breaking changes. Writing `from: "0.4.0"` instead would let Swift Package Manager move you to any later 0.x version on the next resolve.

That is the whole setup. There is no `Info.plist` entry, no build phase, and no initialization call - the Markdown parser is C and C++ compiled into the package and linked with your app.

:::note
The package is iOS-only because it renders through UIKit (`UITextView` and TextKit) - there is no AppKit or watchOS rendering path. For the same reason, the package's types cannot be exercised from a test process running on the host Mac - test targets that touch them have to run in a simulator or on a device.
:::

## The products {#products}

| Product | What it is | Add it? |
| --- | --- | --- |
| `EnrichedMarkdown` | `EnrichedMarkdownText`, the theme DSL, the parser, and `MarkdownRenderer` for rendering into an `NSAttributedString` from UIKit code | **Yes** - this is the package |
| `EnrichedMarkdownSyntaxHighlighting` | Syntax coloring for fenced code blocks, built on tree-sitter with 14 bundled grammars (about 8 MB of app size) | Only if you want highlighted code - see [Syntax highlighting](/ios/guides/syntax-highlighting) |
| `EnrichedMarkdownLaTeX` | `$…$` and `$$…$$` typesetting, plus the two math theme elements. Links a prebuilt typesetting engine and the KaTeX font files (about 3-5 MB of app size) | Only if you render math - see [LaTeX math](/ios/guides/latex-math) |

The optional products are not switched on by being linked. Each one needs its `import` and a modifier on the view (or on a container above it):

```swift
import EnrichedMarkdown
import EnrichedMarkdownLaTeX
import EnrichedMarkdownSyntaxHighlighting
import SwiftUI

struct DocsView: View {
  let markdown: String

  var body: some View {
    ScrollView {
      EnrichedMarkdownText(markdown)
        .markdownSyntaxHighlighting()
        .markdownLaTeX()
    }
  }
}
```

An app that does not add an optional product to its target does not link it, so it adds nothing to the app's size. It is still part of the package graph, though: resolving the package downloads the prebuilt RaTeX xcframework the LaTeX product depends on (from the URL pinned in the package's `Package.swift`) even if you only use `EnrichedMarkdown`.

## Next steps

You're set up. Next let's [put Markdown on the screen](/ios/basics/your-first-screen).
