import SwiftUI

private typealias Semantic = ThemeColorSpec.SemanticColor

enum DefaultMarkdownTheme {
    static func make() -> MarkdownTheme {
        MarkdownTheme {
            Paragraph()
                .font(.body)
                .foregroundStyle(Semantic.primary)
                .lineHeight(26)
                .marginBottom(16)

            Strong()
            Emphasis()
        }
    }
}
