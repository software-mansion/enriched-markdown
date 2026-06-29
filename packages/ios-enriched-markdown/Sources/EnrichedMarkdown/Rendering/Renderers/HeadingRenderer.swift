import UIKit

final class HeadingRenderer: NodeRenderer {
    private let factory: RendererFactory
    private let config: MarkdownStyleConfig

    init(factory: RendererFactory, config: MarkdownStyleConfig) {
        self.factory = factory
        self.config = config
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let level = headingLevel(from: node)
        let headingStyle = config.headingStyle(for: level)

        let font = headingStyle.font ?? defaultFont(for: level)
        let color = headingStyle.foregroundColor ?? UIColor.label
        context.setBlockStyle(font: font, color: color, blockType: .heading, headingLevel: level)

        let start = output.length
        let marginTop = headingStyle.marginTop ?? 0
        var contentStart = start

        if start == 0, marginTop > 0 {
            let offset = ParagraphStyleHelpers.applyBlockSpacingBefore(
                to: output,
                at: 0,
                marginTop: marginTop
            )
            contentStart += offset
        }

        factory.renderChildren(of: node, into: output, context: context)
        context.clearBlockStyle()

        guard output.length > start else { return }

        let range = NSRange(location: start, length: output.length - start)

        if let lineHeight = headingStyle.lineHeight {
            ParagraphStyleHelpers.applyBlockLineHeight(to: output, range: range, lineHeight: lineHeight)
        }

        if let alignment = headingStyle.textAlignment {
            ParagraphStyleHelpers.applyTextAlignment(to: output, range: range, alignment: alignment)
        }

        var spacingStart = start
        if contentStart != 1 {
            spacingStart += ParagraphStyleHelpers.applyParagraphSpacingBefore(
                to: output,
                range: range,
                marginTop: marginTop
            )
        }

        if let marginBottom = headingStyle.marginBottom {
            ParagraphStyleHelpers.applyParagraphSpacingAfter(
                to: output,
                at: spacingStart,
                marginBottom: marginBottom
            )
        }
    }

    private func headingLevel(from node: MarkdownASTNode) -> Int {
        guard let levelString = node.attribute("level"), let level = Int(levelString) else {
            return 1
        }
        return max(1, min(level, 6))
    }

    private func defaultFont(for level: Int) -> UIFont {
        UIFont.systemFont(ofSize: Self.defaultPointSize(for: level), weight: .regular)
    }

    /// Matches Android `DefaultStyles` heading sizes and regular (400) weight.
    private static func defaultPointSize(for level: Int) -> CGFloat {
        switch level {
        case 1: return 30
        case 2: return 24
        case 3: return 20
        case 4: return 18
        case 5: return 16
        default: return 14
        }
    }
}
