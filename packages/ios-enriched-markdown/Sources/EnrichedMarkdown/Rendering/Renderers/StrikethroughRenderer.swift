import UIKit

final class StrikethroughRenderer: NodeRenderer {
    private let factory: RendererFactory
    private let config: MarkdownStyleConfig

    init(factory: RendererFactory, config: MarkdownStyleConfig) {
        self.factory = factory
        self.config = config
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let start = output.length
        factory.renderChildren(of: node, into: output, context: context)

        let range = RenderContext.rangeForRenderedContent(in: output, start: start)
        guard range.length > 0 else { return }

        output.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)

        guard let strikethroughColor = config.strikethrough.foregroundColor else { return }

        output.enumerateAttributes(in: range, options: []) { attributes, subrange, _ in
            guard !RenderContext.shouldPreserveColors(attributes) else { return }

            let currentColor = attributes[.foregroundColor] as? UIColor
            if currentColor != strikethroughColor {
                output.addAttribute(.foregroundColor, value: strikethroughColor, range: subrange)
            }
        }
    }
}
