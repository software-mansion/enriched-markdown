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
            Strikethrough()
            Underline()
            Superscript()
            Subscript()

            // #FEF08A, the highlight background shared with the React Native package.
            Highlight().background(Color(red: 254 / 255, green: 240 / 255, blue: 138 / 255))

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

            quoteStyles

            List()
                .font(.body)
                .foregroundStyle(Semantic.primary)
                .bulletColor(Semantic.secondary)
                .markerColor(Semantic.secondary)
                .gapWidth(12)
                .marginLeft(24)
                .marginBottom(16)

            TaskList()
                .checkedColor(Semantic.tint)
                .borderColor(Semantic.secondary)
                .checkmarkColor(.white)
                .checkboxSize(14)
                .checkboxBorderRadius(3)

            Table()
                .lineHeight(20)
                .foregroundStyle(Semantic.primary)
                .headerTextColor(Semantic.primary)
                .headerBackground(Color(UIColor.tertiarySystemFill))
                .rowOddBackground(Color(UIColor.quaternarySystemFill))
                .borderColor(Color(UIColor.separator))
                .borderWidth(1)
                .cornerRadius(6)
                .cellPaddingHorizontal(12)
                .cellPaddingVertical(8)
                .marginBottom(16)
        }
    }

    /// Split out to keep `make()` under SwiftLint's body length. The alert
    /// palette is GitHub's, shared with the React Native package.
    private static var quoteStyles: MarkdownThemeGroup {
        MarkdownThemeGroup(contents: [
            Blockquote()
                .font(.body)
                .foregroundStyle(Semantic.secondary)
                .borderColor(Semantic.tint)
                .borderWidth(3)
                .gapWidth(16)
                .marginBottom(16),
            Admonition(.note).foregroundStyle(rgb(0x09, 0x69, 0xDA)),
            Admonition(.tip).foregroundStyle(rgb(0x1A, 0x7F, 0x37)),
            Admonition(.important).foregroundStyle(rgb(0x82, 0x50, 0xDF)),
            Admonition(.warning).foregroundStyle(rgb(0x9A, 0x67, 0x00)),
            Admonition(.caution).foregroundStyle(rgb(0xCF, 0x22, 0x2E))
        ])
    }

    private static func rgb(_ red: Int, _ green: Int, _ blue: Int) -> Color {
        Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }
}
