import SwiftUI
import UIKit

public struct EnrichedMarkdownText: View {
    private let markdown: String
    private let options: MarkdownParsingOptions

    @Environment(\.markdownThemeLayers) private var themeLayers
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    @Environment(\.markdownLinkPressHandler) private var onLinkPress
    @Environment(\.markdownLinkLongPressHandler) private var onLinkLongPress
    @Environment(\.markdownSelectionMenu) private var selectionMenuConfig
    @Environment(\.markdownSelectable) private var isSelectionEnabled
    @Environment(\.markdownSelectionColor) private var selectionColor
    @Environment(\.markdownImageRequestHeaders) private var imageRequestHeaders
    @Environment(\.markdownRenderPlugins) private var renderPlugins
    @Environment(\.markdownTaskListItemToggleHandler) private var onTaskListItemToggle
    @Environment(\.markdownTaskListItemToggleEnabled) private var isTaskListToggleEnabled
    @Environment(\.markdownSpoilerOverlay) private var spoilerOverlay
    @Environment(\.markdownAccessibilityLabels) private var accessibilityLabels
    @Environment(\.markdownWritingDirection) private var writingDirection
    // The fallback for paragraphs with no strong directional character.
    @Environment(\.layoutDirection) private var layoutDirection
    @StateObject private var renderStore = MarkdownRenderStore()

    public init(_ markdown: String, options: MarkdownParsingOptions = .commonMark) {
        self.markdown = markdown
        self.options = options
    }

    private var styleConfig: MarkdownStyleConfiguration {
        let traitCollection = ThemeResolver.traitCollection(
            colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize
        )
        // Plugin defaults go above `MarkdownTheme.default` (the environment's
        // first layer) and below the app's themes.
        var layers = themeLayers
        layers.insert(contentsOf: renderPlugins.compactMap(\.defaultTheme), at: min(1, layers.count))
        return MarkdownStyleConfiguration.resolve(layers: layers, traitCollection: traitCollection)
    }

    public var body: some View {
        // Resolved once: `styleConfig` rebuilds the whole config on each read.
        let config = styleConfig
        let inputs = MarkdownRenderInputs(
            markdown: markdown,
            config: config,
            options: options,
            imageRequestHeaders: imageRequestHeaders,
            writingDirection: writingDirection,
            layoutDirection: layoutDirection
        )
        return MarkdownTextViewRepresentable(
            attributedText: renderStore.attributedText,
            source: renderStore.source,
            styleConfig: config,
            openURL: { openURL($0) },
            onLinkPress: onLinkPress,
            onLinkLongPress: onLinkLongPress,
            selectionMenuConfig: selectionMenuConfig,
            isSelectionEnabled: isSelectionEnabled,
            selectionColor: selectionColor,
            onTaskListItemTap: isTaskListToggleEnabled ? { hit in
                let checked = !hit.checked
                renderStore.applyTaskListToggle(index: hit.index, checked: checked, config: config)
                onTaskListItemToggle?(
                    TaskListItemToggle(index: hit.index, isChecked: checked, text: hit.itemText)
                )
            } : nil,
            spoilerOverlay: spoilerOverlay,
            onSpoilerTap: { range in
                renderStore.revealSpoiler(in: range)
            },
            accessibilityLabels: accessibilityLabels
        )
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            renderStore.schedule(inputs, plugins: renderPlugins)
        }
        // Runs against the previous view value, so the render takes the
        // closure's inputs; the view's would be one update behind.
        .onChange(of: inputs) { newValue in
            renderStore.schedule(newValue, plugins: renderPlugins)
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
                .border(.orange, width: 4)
        }
    )
}
#endif
