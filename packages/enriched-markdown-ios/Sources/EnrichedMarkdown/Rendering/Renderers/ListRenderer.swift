import UIKit

final class ListRenderer: NodeRenderer {
    private let factory: RendererFactory
    private let config: MarkdownStyleConfiguration
    private let isOrdered: Bool

    init(factory: RendererFactory, config: MarkdownStyleConfiguration, isOrdered: Bool) {
        self.factory = factory
        self.config = config
        self.isOrdered = isOrdered
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let prevDepth = context.listDepth
        let prevType = context.listType
        let prevNumber = context.listItemNumber
        let prevMarkerWidth = context.listMarkerWidth
        let prevMarkerExtra = context.listMarkerExtra
        let prevMarkerOffset = context.listMarkerOffset
        let startLocation = output.length

        if prevDepth == 0 {
            ParagraphStyleHelpers.ensureStartingOnNewLine(in: output)
            _ = ParagraphStyleHelpers.applyBlockSpacingBefore(
                to: output,
                at: startLocation,
                marginTop: config.list.marginTop ?? 0
            )
        } else {
            ParagraphStyleHelpers.ensureStartingOnNewLine(in: output)
        }

        context.listDepth = prevDepth + 1
        context.listType = isOrdered ? .ordered : .unordered
        context.listItemNumber = 0
        if prevDepth > 0 {
            context.listMarkerOffset += context.listItemMarkerExtra
        }
        let defaultMarkerWidth = ListItemRenderer.defaultMarkerWidth(for: .ordered, config: config)
        context.listMarkerWidth = isOrdered ? widestMarkerWidth(of: node, atLeast: defaultMarkerWidth) : 0
        context.listMarkerExtra = isOrdered ? context.listMarkerWidth - defaultMarkerWidth : 0

        let font = config.list.font ?? UIFont.preferredFont(forTextStyle: .body)
        let color = config.list.foregroundColor ?? UIColor.label
        context.setBlockStyle(
            font: font,
            color: color,
            blockType: isOrdered ? .orderedList : .unorderedList
        )

        factory.renderChildren(of: node, into: output, context: context)

        context.listDepth = prevDepth
        context.listType = prevType
        context.listItemNumber = prevNumber
        context.listMarkerWidth = prevMarkerWidth
        context.listMarkerExtra = prevMarkerExtra
        context.listMarkerOffset = prevMarkerOffset

        if prevDepth == 0 {
            context.clearBlockStyle()
            if let marginBottom = config.list.marginBottom, marginBottom > 0 {
                ParagraphStyleHelpers.applyBlockSpacingAfter(to: output, marginBottom: marginBottom)
            }
        }
    }

    /// Widens the marker column to the list's widest number, so markers are
    /// never drawn past the column's leading edge. Task items draw a checkbox
    /// instead of a number and do not count.
    private func widestMarkerWidth(of node: MarkdownASTNode, atLeast minimumWidth: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: config.list.font ?? BlockDecorationConfig.defaultListMarkerFont
        ]
        var width = minimumWidth
        var number = 0
        for item in node.children where item.type == .listItem {
            number += 1
            guard item.attribute("isTask") != "true" else { continue }
            width = max(width, ("\(number)." as NSString).size(withAttributes: attributes).width)
        }
        return width
    }
}
