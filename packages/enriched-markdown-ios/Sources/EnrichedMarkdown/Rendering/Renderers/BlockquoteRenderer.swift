import UIKit

final class BlockquoteRenderer: NodeRenderer {
    private let factory: RendererFactory
    private let config: MarkdownStyleConfig

    init(factory: RendererFactory, config: MarkdownStyleConfig) {
        self.factory = factory
        self.config = config
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let currentDepth = context.blockquoteDepth
        context.blockquoteDepth = currentDepth + 1

        let blockStyle = config.blockquote
        let font = blockStyle.font ?? UIFont.preferredFont(forTextStyle: .body)
        let color = blockStyle.foregroundColor ?? UIColor.label
        context.setBlockStyle(font: font, color: color, blockType: .blockquote)

        if currentDepth > 0 {
            ParagraphStyleHelpers.ensureStartingOnNewLine(in: output)
        }

        let start = output.length
        factory.renderChildren(of: node, into: output, context: context)
        context.clearBlockStyle()
        context.blockquoteDepth = currentDepth

        guard output.length > start else { return }

        applyStylingAndSpacing(
            to: output,
            start: start,
            end: output.length,
            currentDepth: currentDepth
        )
    }

    private func applyStylingAndSpacing(
        to output: NSMutableAttributedString,
        start: Int,
        end: Int,
        currentDepth: Int
    ) {
        var contentStart = start
        if currentDepth == 0 {
            contentStart += ParagraphStyleHelpers.applyBlockSpacingBefore(
                to: output,
                at: start,
                marginTop: config.blockquote.marginTop ?? 0
            )
        }

        let blockquoteRange = NSRange(location: contentStart, length: end - start)
        let levelSpacing = (config.blockquote.borderWidth ?? 3) + (config.blockquote.gapWidth ?? 16)
        let nestedInfo = collectNestedBlockquotes(in: output, range: blockquoteRange, depth: currentDepth)

        applyBaseBlockquoteStyle(
            to: output,
            range: blockquoteRange,
            depth: currentDepth,
            levelSpacing: levelSpacing
        )

        reapplyNestedStyles(in: output, nestedInfo: nestedInfo, levelSpacing: levelSpacing)

        if currentDepth == 0, let marginBottom = config.blockquote.marginBottom, marginBottom > 0 {
            ParagraphStyleHelpers.applyBlockSpacingAfter(to: output, marginBottom: marginBottom)
        }
    }

    private struct NestedBlockquoteInfo {
        let depth: Int
        let range: NSRange
    }

    private func collectNestedBlockquotes(
        in output: NSMutableAttributedString,
        range: NSRange,
        depth: Int
    ) -> [NestedBlockquoteInfo] {
        var nestedInfo: [NestedBlockquoteInfo] = []

        output.enumerateAttribute(MarkdownAttribute.blockquoteDepth, in: range, options: []) { value, subrange, _ in
            guard let nestedDepth = MarkdownAttributeValue.intValue(from: value), nestedDepth > depth else { return }
            nestedInfo.append(NestedBlockquoteInfo(depth: nestedDepth, range: subrange))
        }

        return nestedInfo
    }

    private func applyBaseBlockquoteStyle(
        to output: NSMutableAttributedString,
        range: NSRange,
        depth: Int,
        levelSpacing: CGFloat
    ) {
        let paragraphStyle = ParagraphStyleHelpers.getOrCreateParagraphStyle(in: output, at: range.location)
        let totalIndent = CGFloat(depth + 1) * levelSpacing
        paragraphStyle.firstLineHeadIndent = totalIndent
        paragraphStyle.headIndent = totalIndent

        var attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle,
            MarkdownAttribute.blockquoteDepth: depth
        ]

        if let backgroundColor = config.blockquote.backgroundColor {
            attributes[MarkdownAttribute.blockquoteBackgroundColor] = backgroundColor
        }

        output.addAttributes(attributes, range: range)

        if let lineHeight = config.blockquote.lineHeight {
            ParagraphStyleHelpers.applyBlockLineHeight(to: output, range: range, lineHeight: lineHeight)
        }
    }

    private func reapplyNestedStyles(
        in output: NSMutableAttributedString,
        nestedInfo: [NestedBlockquoteInfo],
        levelSpacing: CGFloat
    ) {
        for info in nestedInfo {
            let style = ParagraphStyleHelpers.getOrCreateParagraphStyle(in: output, at: info.range.location)
            let indent = CGFloat(info.depth + 1) * levelSpacing
            style.firstLineHeadIndent = indent
            style.headIndent = indent
            style.tailIndent = 0

            output.addAttributes(
                [
                    .paragraphStyle: style,
                    MarkdownAttribute.blockquoteDepth: info.depth
                ],
                range: info.range
            )
        }
    }
}
