import SwiftUI
import UIKit

public struct EnrichedMarkdownText: View {
    private let markdown: String

    @Environment(\.markdownThemeLayers) private var themeLayers
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.markdownLinkPressHandler) private var onLinkPress
    @StateObject private var renderStore = MarkdownRenderStore()

    public init(_ markdown: String) {
        self.markdown = markdown
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
            styleConfig: styleConfig,
            onLinkPress: onLinkPress
        )
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            renderStore.schedule(markdown: markdown, config: styleConfig)
        }
        .onChange(of: markdown) { newValue in
            renderStore.schedule(markdown: newValue, config: styleConfig)
        }
        .onChange(of: styleConfig) { newValue in
            renderStore.schedule(markdown: markdown, config: newValue)
        }
        .onDisappear {
            renderStore.invalidate()
        }
    }
}
