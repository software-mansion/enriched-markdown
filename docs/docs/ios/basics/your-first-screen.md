---
sidebar_label: Your first markdown screen
sidebar_position: 2
---

# Your first markdown screen

With the package [installed](/ios/basics/installation), let's get Markdown onto the screen. By the end of this page you'll have rendered your first document and restyled it.

## Rendering Markdown

`EnrichedMarkdownText` is a SwiftUI view that takes a Markdown string and paints it as **fully native text** - no WebView, and no intermediate HTML. It parses with [md4c](https://github.com/mity/md4c) and renders through TextKit, so selection, VoiceOver, and Dynamic Type behave the way they do in any other text view.

```swift
import EnrichedMarkdown
import SwiftUI

struct ArticleView: View {
  var body: some View {
    ScrollView {
      EnrichedMarkdownText("# Hello\n\nA paragraph with **bold** and a [link](https://swmansion.com).")
        .padding()
    }
    .onLinkPress { url in
      UIApplication.shared.open(url)
    }
  }
}
```

That's the whole setup. The view sizes itself to its content, which is why it belongs inside a `ScrollView` for anything longer than a screen. Links are inert until you give them a meaning - `onLinkPress` hands you the tapped `URL` and you decide what happens, here opening it in the browser.

Everything except the Markdown string itself is configured through **view modifiers** rather than initializer parameters, and each one reads from the SwiftUI environment. That means you can set a handler once on a container and have every `EnrichedMarkdownText` beneath it pick the handler up - which is why `.onLinkPress` sits on the `ScrollView` above rather than on the text. The [`EnrichedMarkdownText` reference](/ios/api-reference/enriched-markdown-text) covers every modifier.

:::note
Rendering happens **off the main thread**. The view paints empty for the first frame or two of a long document and then swaps in the finished text, rather than blocking the main thread while it parses.
:::

## Styling it

Every element is styled through the `MarkdownTheme { }` builder. Build a theme once and apply it with `.markdownTheme` - on a container to set the default for a subtree, or on a single view when one has to differ:

```swift
import EnrichedMarkdown
import SwiftUI

let appTheme = MarkdownTheme {
  Paragraph()
    .font(.body)
    .lineHeight(26)
    .marginBottom(16)

  Heading(1)
    .font(.largeTitle)
    .bold()

  Link()
    .foregroundStyle(.blue)
    .underline()
}

struct RootView: View {
  var body: some View {
    ArticleView()
      .markdownTheme(appTheme)
  }
}
```

Themes **layer**: each `.markdownTheme` stacks on top of the ones above it and on the built-in `MarkdownTheme.default`, and a layer overrides only the properties it sets. So a theme is a set of differences rather than a full stylesheet you have to fill in. For the elements you can open and the properties each takes, see [Style properties](/ios/api-reference/style-properties); for how themes are provided and layered, see [`MarkdownTheme`](/ios/api-reference/markdown-theme).

## Editor on iOS

This package **renders** Markdown; it does not edit it. There is no editable rich text field here yet - no live formatting as the reader types, no format bar, no imperative editing API. If you need one today, you'll have to build it over a `UITextView` or `TextEditor` yourself and render the result with `EnrichedMarkdownText`. An editor is on the [roadmap](/misc/roadmap#the-editor-on-native).

## Next steps

You have a working screen. From here:

- [`EnrichedMarkdownText`](/ios/api-reference/enriched-markdown-text) - every modifier, callback, and parser flag.
- [Parser extensions](/ios/guides/parser-extensions) - turning on the syntax that is off by default, such as underline, super/subscript, and GitHub alerts.
- [Core concepts](/introduction/core-concepts) - the ideas behind the library.
- [Feature support](/introduction/supported-features) - the full matrix of what's supported.
