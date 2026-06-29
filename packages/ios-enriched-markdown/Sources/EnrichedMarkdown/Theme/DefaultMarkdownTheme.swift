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

            Heading(1)
                .font(.largeTitle)
                .bold()
                .foregroundStyle(Semantic.primary)
                .marginBottom(8)

            Heading(2)
                .font(.title)
                .bold()
                .foregroundStyle(Semantic.primary)
                .marginBottom(8)

            Heading(3)
                .font(.title2)
                .bold()
                .foregroundStyle(Semantic.primary)
                .marginBottom(8)

            Heading(4)
                .font(.title3)
                .bold()
                .foregroundStyle(Semantic.primary)
                .marginBottom(8)

            Heading(5)
                .font(.headline)
                .foregroundStyle(Semantic.primary)
                .marginBottom(8)

            Heading(6)
                .font(.subheadline)
                .foregroundStyle(Semantic.secondary)
                .marginBottom(8)

            Link()
                .foregroundStyle(Semantic.tint)
                .underline()

            Strong()
            Emphasis()
        }
    }
}
