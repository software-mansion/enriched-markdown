import UIKit

final class ListRenderer: NodeRenderer {
    private let factory: RendererFactory
    private let config: MarkdownStyleConfig
    private let isOrdered: Bool

    init(factory: RendererFactory, config: MarkdownStyleConfig, isOrdered: Bool) {
        self.factory = factory
        self.config = config
        self.isOrdered = isOrdered
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let prevDepth = context.listDepth
        let prevType = context.listType
        let prevNumber = context.listItemNumber
        let startLocation = output.length

        if prevDepth == 0 {
            ParagraphStyleHelpers.ensureStartingOnNewLine(in: output)
            _ = ParagraphStyleHelpers.applyBlockSpacingBefore(
                to: output,
                at: startLocation,
                marginTop: config.list.marginTop ?? 0
            )
        } else if output.length > 0, !output.string.hasSuffix("\n") {
            output.append(ParagraphStyleHelpers.newline)
        }

        context.listDepth = prevDepth + 1
        context.listType = isOrdered ? .ordered : .unordered
        context.listItemNumber = 0

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

        if prevDepth == 0 {
            context.clearBlockStyle()
            if let marginBottom = config.list.marginBottom, marginBottom > 0 {
                ParagraphStyleHelpers.applyBlockSpacingAfter(to: output, marginBottom: marginBottom)
            }
        }
    }
}
