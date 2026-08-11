import SwiftUI
import UIKit

public struct EnrichedMarkdownText: View {
    private let markdown: String
    private let flags: Md4cFlags

    @Environment(\.markdownThemeLayers) private var themeLayers
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.markdownLinkPressHandler) private var onLinkPress
    @Environment(\.markdownSelectionMenu) private var selectionMenuConfig
    @StateObject private var renderStore = MarkdownRenderStore()

    public init(_ markdown: String, flags: Md4cFlags = .commonMark) {
        self.markdown = markdown
        self.flags = flags
    }

    private var styleConfig: MarkdownStyleConfig {
        let traitCollection = ThemeResolver.traitCollection(
            colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize
        )
        return MarkdownStyleConfig.resolve(layers: themeLayers, traitCollection: traitCollection)
    }

    public var body: some View {
        MarkdownTextViewRepresentable(
            attributedText: renderStore.attributedText,
            sourceMarkdown: renderStore.sourceMarkdown,
            styleConfig: styleConfig,
            onLinkPress: onLinkPress,
            selectionMenuConfig: selectionMenuConfig
        )
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            renderStore.schedule(markdown: markdown, config: styleConfig, flags: flags)
        }
        .onChange(of: markdown) { newValue in
            renderStore.schedule(markdown: newValue, config: styleConfig, flags: flags)
        }
        .onChange(of: styleConfig) { newValue in
            renderStore.schedule(markdown: markdown, config: newValue, flags: flags)
        }
        .onChange(of: flags) { newValue in
            renderStore.schedule(markdown: markdown, config: styleConfig, flags: newValue)
        }
        .onDisappear {
            renderStore.invalidate()
        }
    }
}

#if DEBUG
private let previewMarkdown = """
# Enriched Markdown

Paragraphs support **bold**, *italic*, `inline code`, and [links](https://swmansion.com).

## Lists

- First item
- Second item
  1. Nested ordered item
  2. Another one

> Blockquotes render with a border and background.

```swift
let answer = 42
```

---

Final paragraph after a thematic break.
"""

#Preview("Default theme") {
    ScrollView {
        EnrichedMarkdownText(previewMarkdown)
            .padding()
    }
}

#Preview("Default theme, dark") {
    ScrollView {
        EnrichedMarkdownText(previewMarkdown)
            .padding()
    }
    .preferredColorScheme(.dark)
}

#Preview("Custom theme") {
    ScrollView {
        EnrichedMarkdownText(previewMarkdown)
            .padding()
    }
    .markdownTheme(
        MarkdownTheme {
            Heading(1)
                .foregroundStyle(.purple)
            Link()
                .foregroundStyle(.teal)
                .underline(true)
            Blockquote()
                .borderColor(.orange)
                .borderWidth(4)
        }
    )
}
#endif
