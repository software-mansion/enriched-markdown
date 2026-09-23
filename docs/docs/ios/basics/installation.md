---
sidebar_label: Installation
sidebar_position: 1
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Installation

`enriched-markdown-ios` is a **standalone Swift package** - a SwiftUI view that renders Markdown as native text. You add it the way you add any other Swift package, and the Markdown parser is compiled into it - there is no third-party dependency to resolve.

## Requirements

| | |
| --- | --- |
| **Deployment target** | iOS 16.0 |
| **Swift tools** | 5.9 (Xcode 15 or newer) |
| **UI framework** | SwiftUI - the package exports a `View` |
| **Dependency manager** | Swift Package Manager |

For the supported versions, see [Compatibility](/misc/compatibility).

## Add the package

<Tabs groupId="spm">
  <TabItem value="xcode" label="Xcode">

**File → Add Package Dependencies…**, enter the repository URL:

```
https://github.com/software-mansion-labs/enriched-markdown-ios
```

then add the **`EnrichedMarkdown`** product to your app target. Add **`EnrichedMarkdownLaTeX`** as well only if you render formulas - see [LaTeX math](/ios/guides/latex-math).

  </TabItem>
  <TabItem value="manifest" label="Package.swift">

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

  </TabItem>
</Tabs>

That is the whole setup. There is no `Info.plist` entry, no build phase, and no initialization call - the Markdown parser is C and C++ compiled into the package and linked with your app.

:::note
The package builds for **iOS only**. Its manifest declares `platforms: [.iOS(.v16)]` and its sources import UIKit, so a macOS, watchOS, or tvOS target cannot depend on it - and neither can a test target that runs outside a simulator.
:::

## The two products

| Product | What it is | Add it? |
| --- | --- | --- |
| `EnrichedMarkdown` | `EnrichedMarkdownText`, the theme DSL, and the parser | **Yes** - this is the package |
| `EnrichedMarkdownLaTeX` | `$…$` and `$$…$$` typesetting, plus the two math theme elements | Only if you render math |

`EnrichedMarkdownLaTeX` pulls in a prebuilt typesetting engine as a binary dependency and the KaTeX font files, which is why it is separate: an app that never shows a formula does not pay for it. See [LaTeX math](/ios/guides/latex-math) for what it costs and how to turn it on.

## Next steps

You're set up. Next let's [put Markdown on the screen](/ios/basics/your-first-screen).
