import UIKit

extension MarkdownHTMLGenerator {
    struct CachedStyles {
        let paragraphColor: String
        let paragraphFontSize: Int
        let paragraphMarginBottom: Int

        let codeBlockColor: String
        let codeBlockBgColor: String
        let codeBlockFontSize: Int
        let codeBlockPadding: Int
        let codeBlockBorderRadius: Int
        let codeBlockMarginBottom: Int

        let codeColor: String
        let codeBgColor: String

        let highlightOpenTag: String

        let blockquoteColor: String
        let blockquoteBgColor: String
        let blockquoteBorderColor: String
        let blockquoteBorderWidth: Int
        let blockquoteGapWidth: Int
        let blockquoteMarginBottom: Int
        let blockquoteFontSize: Int

        let listColor: String
        let listFontSize: Int
        let listMarginBottom: Int
        let listMarginLeft: Int

        let linkColor: String
        let linkUnderline: Bool

        let strongColor: String?
        let emphasisColor: String?

        let imageMarginBottom: Int
        let imageBorderRadius: Int

        let headingFontSizes: [Int]
        let headingFontWeights: [String]
        let headingColors: [String]
        let headingMarginBottoms: [Int]

        init(config: MarkdownStyleConfig) {
            let bodySize = Int(UIFont.preferredFont(forTextStyle: .body).pointSize)

            paragraphColor = cssColor(config.paragraph.foregroundColor)
            paragraphFontSize = config.paragraph.font.map { Int($0.pointSize) } ?? bodySize
            paragraphMarginBottom = Int(config.paragraph.marginBottom ?? 0)

            codeBlockColor = cssColor(config.codeBlock.foregroundColor)
            codeBlockBgColor = cssColor(config.codeBlock.backgroundColor)
            codeBlockFontSize = config.codeBlock.font.map { Int($0.pointSize) } ?? bodySize
            codeBlockPadding = Int(config.codeBlock.padding ?? 0)
            codeBlockBorderRadius = Int(config.codeBlock.borderRadius ?? 0)
            codeBlockMarginBottom = Int(config.codeBlock.marginBottom ?? 0)

            codeColor = cssColor(config.code.foregroundColor)
            codeBgColor = cssColor(config.code.backgroundColor)

            let highlightStyle = [
                config.highlight.backgroundColor.map { "background-color: \(cssColor($0));" },
                config.highlight.foregroundColor.map { "color: \(cssColor($0));" }
            ].compactMap { $0 }.joined(separator: " ")
            highlightOpenTag = highlightStyle.isEmpty ? "<mark>" : "<mark style=\"\(highlightStyle)\">"

            blockquoteColor = cssColor(config.blockquote.foregroundColor)
            blockquoteBgColor = cssColor(config.blockquote.backgroundColor)
            blockquoteBorderColor = cssColor(config.blockquote.borderColor)
            blockquoteBorderWidth = Int(config.blockquote.borderWidth ?? 0)
            blockquoteGapWidth = Int(config.blockquote.gapWidth ?? 0)
            blockquoteMarginBottom = Int(config.blockquote.marginBottom ?? 0)
            blockquoteFontSize = config.blockquote.font.map { Int($0.pointSize) } ?? bodySize

            listColor = cssColor(config.list.foregroundColor)
            listFontSize = config.list.font.map { Int($0.pointSize) } ?? bodySize
            listMarginBottom = Int(config.list.marginBottom ?? 0)
            listMarginLeft = Int(config.list.marginLeft ?? 24)

            linkColor = cssColor(config.link.foregroundColor)
            linkUnderline = config.link.underline ?? true

            strongColor = config.strong.foregroundColor.map(cssColor)
            emphasisColor = config.emphasis.foregroundColor.map(cssColor)

            imageMarginBottom = Int(config.image.marginBottom ?? 0)
            imageBorderRadius = Int(config.image.borderRadius ?? 0)

            let headings = [
                config.heading1, config.heading2, config.heading3,
                config.heading4, config.heading5, config.heading6
            ]
            headingFontSizes = headings.map { $0.font.map { Int($0.pointSize) } ?? bodySize }
            headingFontWeights = headings.map { heading in
                let isBold = heading.font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? true
                return isBold ? "700" : "normal"
            }
            headingColors = headings.map { cssColor($0.foregroundColor) }
            headingMarginBottoms = headings.map { Int($0.marginBottom ?? 0) }
        }
    }

    private static func cssColor(_ color: UIColor?) -> String {
        guard let color else { return "inherit" }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return "inherit" }

        let redByte = Int(round(min(max(red, 0), 1) * 255))
        let greenByte = Int(round(min(max(green, 0), 1) * 255))
        let blueByte = Int(round(min(max(blue, 0), 1) * 255))
        if alpha < 1 {
            let alphaString = String(format: "%.2f", alpha)
            return "rgba(\(redByte), \(greenByte), \(blueByte), \(alphaString))"
        }
        return String(format: "#%02X%02X%02X", redByte, greenByte, blueByte)
    }
}
