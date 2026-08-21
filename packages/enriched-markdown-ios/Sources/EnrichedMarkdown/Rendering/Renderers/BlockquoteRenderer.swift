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
        var attributes: [NSAttributedString.Key: Any] = [
            MarkdownAttribute.blockquoteDepth: depth
        ]

        if let backgroundColor = config.blockquote.backgroundColor {
            attributes[MarkdownAttribute.blockquoteBackgroundColor] = backgroundColor
        }

        output.addAttributes(attributes, range: range)
        applyIndentSkippingListItems(to: output, range: range, indent: CGFloat(depth + 1) * levelSpacing)

        if let lineHeight = config.blockquote.lineHeight {
            ParagraphStyleHelpers.applyBlockLineHeight(to: output, range: range, lineHeight: lineHeight)
        }
    }

    /// List items position themselves inside blockquotes (their indent
    /// already includes the quote offset, and it must not be overwritten or
    /// their marker column collapses onto the quote border), so the quote
    /// indent is applied per paragraph, skipping list-item paragraphs.
    private func applyIndentSkippingListItems(
        to output: NSMutableAttributedString,
        range: NSRange,
        indent: CGFloat
    ) {
        let string = output.string as NSString
        var location = range.location
        let end = NSMaxRange(range)

        while location < end {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            let applyRange = NSIntersectionRange(paragraphRange, range)
            guard applyRange.length > 0 else { break }
            location = NSMaxRange(applyRange)

            if output.attribute(MarkdownAttribute.listDepth, at: applyRange.location, effectiveRange: nil) != nil {
                continue
            }

            let style = ParagraphStyleHelpers.getOrCreateParagraphStyle(in: output, at: applyRange.location)
            style.firstLineHeadIndent = indent
            style.headIndent = indent
            style.tailIndent = 0
            output.addAttribute(.paragraphStyle, value: style, range: applyRange)
        }
    }

    private func reapplyNestedStyles(
        in output: NSMutableAttributedString,
        nestedInfo: [NestedBlockquoteInfo],
        levelSpacing: CGFloat
    ) {
        for info in nestedInfo {
            output.addAttributes([MarkdownAttribute.blockquoteDepth: info.depth], range: info.range)
            applyIndentSkippingListItems(
                to: output,
                range: info.range,
                indent: CGFloat(info.depth + 1) * levelSpacing
            )
        }
    }
}
