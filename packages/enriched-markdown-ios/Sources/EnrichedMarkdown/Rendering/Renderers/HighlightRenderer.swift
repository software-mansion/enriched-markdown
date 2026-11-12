import UIKit

final class HighlightRenderer: NodeRenderer {
    private let factory: RendererFactory
    private let config: MarkdownStyleConfiguration

    init(factory: RendererFactory, config: MarkdownStyleConfiguration) {
        self.factory = factory
        self.config = config
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let start = output.length
        factory.renderChildren(of: node, into: output, context: context)

        let range = RenderContext.rangeForRenderedContent(in: output, start: start)
        guard range.length > 0 else { return }

        output.addAttribute(MarkdownAttribute.highlight, value: true, range: range)

        if let backgroundColor = config.highlight.backgroundColor {
            var holdsBorder = false
            output.enumerateAttribute(MarkdownAttribute.inlineBackground, in: range, options: []) { value, _, stop in
                holdsBorder = (value as? InlineBackground)?.style.border != nil
                stop.pointee = ObjCBool(holdsBorder)
            }
            let fillKey = holdsBorder ? MarkdownAttribute.drawnHighlight : .backgroundColor
            output.enumerateAttributes(in: range, options: []) { attributes, subrange, _ in
                if let drawn = attributes[MarkdownAttribute.inlineBackground] as? InlineBackground {
                    output.addAttribute(
                        MarkdownAttribute.inlineBackground, value: drawn.beneath(highlight: backgroundColor), range: subrange
                    )
                } else if attributes[MarkdownAttribute.inlineCode] == nil, attributes[.backgroundColor] == nil {
                    output.addAttribute(fillKey, value: backgroundColor, range: subrange)
                }
            }
        }

        let blockColor = context.getBlockStyle()?.color ?? UIColor.label
        if let highlightColor = RenderContext.calculateStrongColor(
            configColor: config.highlight.foregroundColor,
            blockColor: blockColor
        ) {
            RenderContext.applyForegroundColor(highlightColor, to: output, in: range)
        }
    }
}
