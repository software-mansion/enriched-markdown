import SwiftUI

enum DefaultMarkdownTheme {
    static func make() -> MarkdownTheme {
        MarkdownTheme {
            Paragraph()
                .font(.body)
                .foregroundStyle(.primary)
                .lineHeight(26)
                .marginBottom(16)

            headings()

            Link()
                .foregroundStyle(.tint)
                .underline()

            Strong()
            Emphasis()
            Strikethrough()
            Underline()
            Superscript()
            Subscript()

            // #FEF08A, the highlight background shared with the React Native package.
            Highlight().background(Color(red: 254 / 255, green: 240 / 255, blue: 138 / 255))

            Spoiler()
                .foregroundStyle(.secondary)
                .background(Color(UIColor.systemBackground))

            Code()
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
                .background(.quaternary)

            BlockImage()
                .height(200)
                .cornerRadius(8)
                .marginBottom(16)

            InlineImage()
                .size(20)

            ThematicBreak()
                .foregroundStyle(.secondary)
                .height(1)
                .marginTop(24)
                .marginBottom(24)

            CodeBlock()
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .background(.quaternary)
                .cornerRadius(8)
                .padding(12)
                .marginBottom(16)

            quoteStyles

            List()
                .font(.body)
                .foregroundStyle(.primary)
                .bulletColor(.secondary)
                .markerColor(.secondary)
                .gapWidth(12)
                .marginLeading(24)
                .marginBottom(16)

            TaskList()
                .checkedColor(.tint)
                .borderColor(.secondary)
                .checkmarkColor(.white)
                .checkboxSize(14)
                .checkboxCornerRadius(3)

            Table()
                .lineHeight(20)
                .foregroundStyle(.primary)
                .headerForegroundStyle(.primary)
                .headerBackground(Color(UIColor.tertiarySystemFill))
                .rowOddBackground(Color(UIColor.quaternarySystemFill))
                .border(Color(UIColor.separator), width: 1)
                .cornerRadius(6)
                .cellPadding(horizontal: 12, vertical: 8)
                .marginBottom(16)
        }
    }

    /// Split out to keep `make()` under SwiftLint's body length. The alert
    /// palette is GitHub's, shared with the React Native package.
    private static var quoteStyles: MarkdownThemeGroup {
        MarkdownThemeGroup(contents: [
            Blockquote()
                .font(.body)
                .foregroundStyle(.secondary)
                .border(.tint, width: 3)
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

    /// Split out for the same reason as `quoteStyles`.
    @MarkdownThemeBuilder
    private static func headings() -> MarkdownThemeGroup {
        Heading(1)
            .font(.largeTitle)
            .bold()
            .foregroundStyle(.primary)
            .marginBottom(8)

        Heading(2)
            .font(.title)
            .bold()
            .foregroundStyle(.primary)
            .marginBottom(8)

        Heading(3)
            .font(.title2)
            .bold()
            .foregroundStyle(.primary)
            .marginBottom(8)

        Heading(4)
            .font(.title3)
            .bold()
            .foregroundStyle(.primary)
            .marginBottom(8)

        Heading(5)
            .font(.headline)
            .foregroundStyle(.primary)
            .marginBottom(8)

        Heading(6)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .marginBottom(8)
    }
}
