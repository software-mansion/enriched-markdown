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

            Code()
                .fontDesign(.monospaced)
                .foregroundStyle(Semantic.secondary)
                .background(Semantic.quaternary)

            BlockImage()
                .height(200)
                .borderRadius(8)
                .marginBottom(16)

            InlineImage()
                .size(20)

            ThematicBreak()
                .foregroundStyle(Semantic.secondary)
                .height(1)
                .marginTop(24)
                .marginBottom(24)

            CodeBlock()
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Semantic.primary)
                .background(Semantic.quaternary)
                .cornerRadius(8)
                .padding(12)
                .marginBottom(16)

            Blockquote()
                .font(.body)
                .foregroundStyle(Semantic.secondary)
                .borderColor(Semantic.tint)
                .borderWidth(3)
                .gapWidth(16)
                .marginBottom(16)

            List()
                .font(.body)
                .foregroundStyle(Semantic.primary)
                .bulletColor(Semantic.secondary)
                .markerColor(Semantic.secondary)
                .gapWidth(12)
                .marginLeft(24)
                .marginBottom(16)
        }
    }
}
