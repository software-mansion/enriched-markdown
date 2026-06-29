import UIKit

final class StrongRenderer: NodeRenderer {
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

        let blockStyle = context.getBlockStyle()
        let blockColor = blockStyle?.color ?? UIColor.label
        let strongColor = RenderContext.calculateStrongColor(
            configColor: config.strong.foregroundColor,
            blockColor: blockColor
        )

        output.enumerateAttributes(in: range, options: []) { attributes, subrange, _ in
            let currentFont = (attributes[.font] as? UIFont) ?? FontHelpers.cachedFont(from: blockStyle)
            let resolvedFont = FontHelpers.ensureBold(currentFont) ?? currentFont

            if let currentFont, resolvedFont != currentFont {
                output.addAttribute(.font, value: resolvedFont, range: subrange)
            }

            if let strongColor, !RenderContext.shouldPreserveColors(attributes) {
                let currentColor = attributes[.foregroundColor] as? UIColor
                if currentColor != strongColor {
                    output.addAttribute(.foregroundColor, value: strongColor, range: subrange)
                }
            }
        }
    }
}
