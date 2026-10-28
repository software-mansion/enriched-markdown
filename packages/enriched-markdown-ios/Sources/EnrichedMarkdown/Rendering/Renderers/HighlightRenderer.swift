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
            output.enumerateAttributes(in: range, options: []) { attributes, subrange, _ in
                guard !RenderContext.shouldPreserveBackground(attributes) else { return }
                output.addAttribute(.backgroundColor, value: backgroundColor, range: subrange)
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
