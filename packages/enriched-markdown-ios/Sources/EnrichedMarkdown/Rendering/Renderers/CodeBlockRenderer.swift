import UIKit

final class CodeBlockRenderer: NodeRenderer {
    private let factory: RendererFactory
    private let config: MarkdownStyleConfig

    init(factory: RendererFactory, config: MarkdownStyleConfig) {
        self.factory = factory
        self.config = config
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let blockStyle = config.codeBlock
        let font = blockStyle.font ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        let color = blockStyle.foregroundColor ?? UIColor.label
        context.setBlockStyle(font: font, color: color, blockType: .codeBlock)

        let padding = blockStyle.padding ?? 0
        let lineHeight = blockStyle.lineHeight ?? 0
        let marginTop = blockStyle.marginTop ?? 0
        let marginBottom = blockStyle.marginBottom ?? 0

        ParagraphStyleHelpers.ensureStartingOnNewLine(in: output)

        var blockStart = output.length
        blockStart += ParagraphStyleHelpers.applyBlockSpacingBefore(
            to: output,
            at: blockStart,
            marginTop: marginTop
        )

        if padding > 0 {
            let topSpacerLocation = output.length
            output.append(ParagraphStyleHelpers.newline)
            let topSpacerStyle = ParagraphStyleHelpers.spacerParagraphStyle(height: padding)
            topSpacerStyle.baseWritingDirection = .leftToRight
            output.addAttribute(
                .paragraphStyle,
                value: topSpacerStyle,
                range: NSRange(location: topSpacerLocation, length: 1)
            )
        }

        let contentStart = output.length
        factory.renderChildren(of: node, into: output, context: context)
        context.clearBlockStyle()

        guard output.length > contentStart else { return }

        let contentRange = NSRange(location: contentStart, length: output.length - contentStart)
        let codeFont = blockStyle.font ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)

        if let codeColor = blockStyle.foregroundColor {
            output.addAttributes(
                [.font: codeFont, .foregroundColor: codeColor],
                range: contentRange
            )
        } else {
            output.addAttribute(.font, value: codeFont, range: contentRange)
        }

        let baseStyle = ParagraphStyleHelpers.getOrCreateParagraphStyle(in: output, at: contentStart)
        baseStyle.baseWritingDirection = .leftToRight
        baseStyle.alignment = .left
        baseStyle.firstLineHeadIndent = padding
        baseStyle.headIndent = padding
        baseStyle.tailIndent = -padding
        output.addAttribute(.paragraphStyle, value: baseStyle, range: contentRange)

        if lineHeight > 0 {
            ParagraphStyleHelpers.applyBlockLineHeight(to: output, range: contentRange, lineHeight: lineHeight)
        }

        if padding > 0 {
            let bottomSpacerLocation = output.length
            output.append(ParagraphStyleHelpers.newline)
            let bottomSpacerStyle = ParagraphStyleHelpers.spacerParagraphStyle(height: padding)
            bottomSpacerStyle.baseWritingDirection = .leftToRight
            output.addAttribute(
                .paragraphStyle,
                value: bottomSpacerStyle,
                range: NSRange(location: bottomSpacerLocation, length: 1)
            )
        }

        let backgroundRange = NSRange(location: blockStart, length: output.length - blockStart)
        output.addAttribute(MarkdownAttribute.codeBlock, value: true, range: backgroundRange)

        if marginBottom > 0 {
            ParagraphStyleHelpers.applyBlockSpacingAfter(to: output, marginBottom: marginBottom)
        }
    }
}
