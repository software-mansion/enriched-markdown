import UIKit

final class UnderlineRenderer: NodeRenderer {
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

        output.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)

        guard let underlineColor = config.underline.foregroundColor else { return }

        output.enumerateAttributes(in: range, options: []) { attributes, subrange, _ in
            guard !RenderContext.shouldPreserveColors(attributes) else { return }

            let currentColor = attributes[.foregroundColor] as? UIColor
            if currentColor != underlineColor {
                output.addAttribute(.foregroundColor, value: underlineColor, range: subrange)
            }
        }
    }
}
