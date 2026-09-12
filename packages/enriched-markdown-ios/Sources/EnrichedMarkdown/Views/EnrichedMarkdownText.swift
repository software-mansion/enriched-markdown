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
    @Environment(\.markdownRenderPlugins) private var renderPlugins
    @Environment(\.markdownTaskListItemPressHandler) private var onTaskListItemPress
    @Environment(\.markdownTaskListItemToggleEnabled) private var isTaskListToggleEnabled
    @Environment(\.markdownAccessibilityLabels) private var accessibilityLabels
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
        // Plugin defaults go above `MarkdownTheme.default` (the environment's
        // first layer) and below the app's themes.
        var layers = themeLayers
        layers.insert(contentsOf: renderPlugins.compactMap(\.defaultTheme), at: min(1, layers.count))
        return MarkdownStyleConfig.resolve(layers: layers, traitCollection: traitCollection)
    }

    public var body: some View {
        // Resolved once: `styleConfig` rebuilds the whole config on each read,
        // and the representable and every `onChange` below read it.
        let config = styleConfig
        return MarkdownTextViewRepresentable(
            attributedText: renderStore.attributedText,
            source: renderStore.source,
            styleConfig: config,
            onLinkPress: onLinkPress,
            onLinkLongPress: onLinkLongPress,
            selectionMenuConfig: selectionMenuConfig,
            isSelectionEnabled: isSelectionEnabled,
            selectionColor: selectionColor,
            onTaskListItemTap: isTaskListToggleEnabled ? { hit in
                let checked = !hit.checked
                renderStore.applyTaskListToggle(index: hit.index, checked: checked, config: config)
                onTaskListItemPress?(
                    TaskListItemPressEvent(index: hit.index, checked: checked, text: hit.itemText)
                )
            } : nil,
            accessibilityLabels: accessibilityLabels
        )
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            renderStore.schedule(
                markdown: markdown,
                config: config,
                flags: flags,
                imageRequestHeaders: imageRequestHeaders,
                plugins: renderPlugins
            )
        }
        // The onChange closures run against the previous view value, so the
        // changed value must come from the closure parameter — reading the
        // view property would render one update behind.
        .onChange(of: markdown) { newValue in
            renderStore.schedule(
                markdown: newValue,
                config: config,
                flags: flags,
                imageRequestHeaders: imageRequestHeaders,
                plugins: renderPlugins
            )
        }
        .onChange(of: config) { newValue in
            renderStore.schedule(
                markdown: markdown,
                config: newValue,
                flags: flags,
                imageRequestHeaders: imageRequestHeaders,
                plugins: renderPlugins
            )
        }
        .onChange(of: flags) { newValue in
            renderStore.schedule(
                markdown: markdown,
                config: config,
                flags: newValue,
                imageRequestHeaders: imageRequestHeaders,
                plugins: renderPlugins
            )
        }
        .onChange(of: imageRequestHeaders) { newValue in
            renderStore.schedule(
                markdown: markdown,
                config: config,
                flags: flags,
                imageRequestHeaders: newValue,
                plugins: renderPlugins
            )
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
