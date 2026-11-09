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
        let prevMarkerOffset = context.ancestorMarkerOffset
        let startLocation = output.length
        let listType: ListType = isOrdered ? .ordered : .unordered
        let isTopLevel = prevDepth == 0 && context.blockquoteDepth == 0
        let continued = isTopLevel ? context.listContinuation.flatMap { $0.type == listType ? $0 : nil } : nil
        context.listContinuation = nil

        ParagraphStyleHelpers.ensureStartingOnNewLine(in: output)
        if prevDepth == 0, continued == nil {
            _ = ParagraphStyleHelpers.applyBlockSpacingBefore(
                to: output,
                at: startLocation,
                marginTop: config.list.marginTop ?? 0
            )
        }

        context.listDepth = prevDepth + 1
        context.listType = listType
        context.listItemNumber = continued?.itemNumber ?? 0
        if prevDepth > 0 {
            context.ancestorMarkerOffset += context.listItemMarkerExtra
        }
        var markerWidth: CGFloat = 0
        if isOrdered {
            markerWidth = widestMarkerWidth(
                of: node,
                after: context.listItemNumber,
                atLeast: config.list.defaultMarkerColumnWidth(for: .ordered)
            )
            if let continued {
                if markerWidth > continued.markerWidth + 0.01 {
                    context.listRestartRequested = true
                }
                markerWidth = max(markerWidth, continued.markerWidth)
            }
        }
        context.listMarkerWidth = markerWidth

        let font = config.list.font ?? UIFont.preferredFont(forTextStyle: .body)
        let color = config.list.foregroundColor ?? UIColor.label
        context.setBlockStyle(
            font: font,
            color: color,
            blockType: isOrdered ? .orderedList : .unorderedList
        )

        factory.renderChildren(of: node, into: output, context: context)

        let itemNumber = context.listItemNumber
        context.listDepth = prevDepth
        context.listType = prevType
        context.listItemNumber = prevNumber
        context.listMarkerWidth = prevMarkerWidth
        context.ancestorMarkerOffset = prevMarkerOffset

        if prevDepth == 0 {
            context.clearBlockStyle()
            context.openList = ListContinuation(type: listType, itemNumber: itemNumber, markerWidth: markerWidth)
            if !context.listContinuedByNext, let marginBottom = config.list.marginBottom, marginBottom > 0 {
                ParagraphStyleHelpers.applyBlockSpacingAfter(to: output, marginBottom: marginBottom)
            }
        }
    }

    /// Widens the marker column to the list's widest number, so markers are
    /// never drawn past the column's leading edge. Task items draw a checkbox
    /// instead of a number and do not count.
    private func widestMarkerWidth(of node: MarkdownASTNode, after lastNumber: Int, atLeast minimumWidth: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: config.list.font ?? BlockDecorationConfig.defaultListMarkerFont
        ]
        var width = minimumWidth
        var number = lastNumber
        for item in node.children where item.type == .listItem {
            number += 1
            guard item.attribute("isTask") != "true" else { continue }
            width = max(width, ("\(number)." as NSString).size(withAttributes: attributes).width)
        }
        return width
    }
}
