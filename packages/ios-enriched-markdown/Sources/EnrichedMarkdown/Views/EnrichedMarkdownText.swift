import SwiftUI
import UIKit

public struct EnrichedMarkdownText: View {
    private let markdown: String

    @Environment(\.markdownStyleConfig) private var styleConfig

    public init(_ markdown: String) {
        self.markdown = markdown
    }

    public var body: some View {
        MarkdownTextViewRepresentable(
            attributedText: MarkdownRenderer.render(markdown, config: styleConfig)
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}
