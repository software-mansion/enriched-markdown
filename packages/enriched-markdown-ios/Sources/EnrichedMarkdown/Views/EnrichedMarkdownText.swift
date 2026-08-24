import SwiftUI
import UIKit

public struct EnrichedMarkdownText: View {
    private let markdown: String
    private let flags: Md4cFlags

    @Environment(\.markdownThemeLayers) private var themeLayers
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.markdownLinkPressHandler) private var onLinkPress
    @Environment(\.markdownLinkLongPressHandler) private var onLinkLongPress
    @Environment(\.markdownSelectionMenu) private var selectionMenuConfig
    @Environment(\.markdownSelectable) private var isSelectionEnabled
    @Environment(\.markdownSelectionColor) private var selectionColor
    @Environment(\.markdownImageRequestHeaders) private var imageRequestHeaders
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
        VStack(alignment: .leading, spacing: 0) {
            ForEach(renderStore.segments) { segment in
                segmentView(for: segment)
            }
        }
        // On the stack, not per segment: as the outermost layout modifier it
        // receives the parent's real width proposal and forwards it to every
        // segment, so heights are measured at the width the segments are
        // actually laid out with. Per-segment fixedSize let an ideal-size
        // probe at a different width supply the final height (25pt of
        // phantom bottom space in containers like ScrollView + padding).
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            renderStore.schedule(
                markdown: markdown,
                config: styleConfig,
                flags: flags,
                imageRequestHeaders: imageRequestHeaders
            )
        }
        // The onChange closures run against the previous view value, so the
        // changed value must come from the closure parameter — reading the
        // view property would render one update behind.
        .onChange(of: markdown) { newValue in
            renderStore.schedule(
                markdown: newValue,
                config: styleConfig,
                flags: flags,
                imageRequestHeaders: imageRequestHeaders
            )
        }
        .onChange(of: styleConfig) { newValue in
            renderStore.schedule(
                markdown: markdown,
                config: newValue,
                flags: flags,
                imageRequestHeaders: imageRequestHeaders
            )
        }
        .onChange(of: flags) { newValue in
            renderStore.schedule(
                markdown: markdown,
                config: styleConfig,
                flags: newValue,
                imageRequestHeaders: imageRequestHeaders
            )
        }
        .onChange(of: imageRequestHeaders) { newValue in
            renderStore.schedule(
                markdown: markdown,
                config: styleConfig,
                flags: flags,
                imageRequestHeaders: newValue
            )
        }
        .onDisappear {
            renderStore.invalidate()
        }
    }

    @ViewBuilder
    private func segmentView(for segment: RenderedMarkdownSegment) -> some View {
        switch segment.content {
        case .text(let attributedText):
            MarkdownTextViewRepresentable(
                attributedText: attributedText,
                sourceMarkdown: renderStore.sourceMarkdown,
                styleConfig: styleConfig,
                onLinkPress: onLinkPress,
                onLinkLongPress: onLinkLongPress,
                selectionMenuConfig: selectionMenuConfig,
                isSelectionEnabled: isSelectionEnabled,
                selectionColor: selectionColor
            )
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
