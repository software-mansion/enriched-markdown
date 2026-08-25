import UIKit

final class ListItemRenderer: NodeRenderer {
    private let factory: RendererFactory
    private let config: MarkdownStyleConfig

    init(factory: RendererFactory, config: MarkdownStyleConfig) {
        self.factory = factory
        self.config = config
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        context.listItemNumber += 1
        let currentPosition = context.listItemNumber
        let currentDepth = context.listDepth
        let nestingLevel = currentDepth - 1

        let startLocation = output.length
        factory.renderChildren(of: node, into: output, context: context)
        ParagraphStyleHelpers.ensureTrailingNewline(in: output)

        let itemRange = NSRange(location: startLocation, length: output.length - startLocation)
        guard itemRange.length > 0 else { return }

        let baseMarkerWidth = effectiveMarkerWidth(for: context.listType)
        let gapWidth = max(config.list.gapWidth ?? 12, 4)
        let marginLeft = config.list.marginLeft ?? 24
        let totalIndent = baseMarkerWidth + gapWidth + (CGFloat(nestingLevel) * marginLeft)
        let lineHeight = config.list.lineHeight ?? 0

        let metadata: [NSAttributedString.Key: Any] = [
            MarkdownAttribute.listDepth: nestingLevel,
            MarkdownAttribute.listType: context.listType.rawValue,
            MarkdownAttribute.listItemNumber: currentPosition
        ]

        applyListItemStyling(
            to: output,
            itemRange: itemRange,
            nestingLevel: nestingLevel,
            metadata: metadata,
            totalIndent: totalIndent,
            lineHeight: lineHeight
        )
    }

    private func effectiveMarkerWidth(for listType: ListType) -> CGFloat {
        let minWidth = config.list.markerMinWidth ?? 0
        switch listType {
        case .ordered:
            return max(minWidth, 20)
        case .unordered:
            return max(minWidth, config.list.bulletSize ?? 6)
        }
    }

    private func applyListItemStyling(
        to output: NSMutableAttributedString,
        itemRange: NSRange,
        nestingLevel: Int,
        metadata: [NSAttributedString.Key: Any],
        totalIndent: CGFloat,
        lineHeight: CGFloat
    ) {
        let string = output.string as NSString
        var location = itemRange.location
        let end = NSMaxRange(itemRange)

        while location < end {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            let applyRange = NSIntersectionRange(paragraphRange, itemRange)
            guard applyRange.length > 0 else { break }

            if shouldSkipListStyling(in: output, range: applyRange, nestingLevel: nestingLevel) {
                location = NSMaxRange(applyRange)
                continue
            }

            let style = NSMutableParagraphStyle()
            style.firstLineHeadIndent = totalIndent
            style.headIndent = totalIndent

            if lineHeight > 0 {
                style.minimumLineHeight = lineHeight
                style.maximumLineHeight = lineHeight
            }

            var attributes = metadata
            attributes[.paragraphStyle] = style
            output.addAttributes(attributes, range: applyRange)

            if lineHeight > 0 {
                ParagraphStyleHelpers.applyBaselineOffset(to: output, range: applyRange)
            }

            location = NSMaxRange(applyRange)
        }
    }

    private func shouldSkipListStyling(
        in output: NSMutableAttributedString,
        range: NSRange,
        nestingLevel: Int
    ) -> Bool {
        if let depth = MarkdownAttributeValue.intValue(
            from: output.attribute(MarkdownAttribute.listDepth, at: range.location, effectiveRange: nil)
        ), depth > nestingLevel {
            return true
        }

        if MarkdownAttributeValue.boolValue(
            from: output.attribute(MarkdownAttribute.codeBlock, at: range.location, effectiveRange: nil)
        ) {
            return true
        }

        return false
    }
}
