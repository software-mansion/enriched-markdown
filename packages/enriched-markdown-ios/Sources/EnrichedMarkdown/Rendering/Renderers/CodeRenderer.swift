import UIKit

final class CodeRenderer: NodeRenderer {
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

        let codeStyle = config.code

        output.enumerateAttributes(in: range, options: []) { attributes, subrange, _ in
            let currentFont = (attributes[.font] as? UIFont) ?? FontHelpers.cachedFont(from: context.getBlockStyle())
            if let resolvedFont = FontHelpers.ensureMonospaced(currentFont, configFont: codeStyle.font) {
                output.addAttribute(.font, value: resolvedFont, range: subrange)
            }

            if let codeColor = codeStyle.foregroundColor {
                output.addAttribute(.foregroundColor, value: codeColor, range: subrange)
            }

            if let backgroundColor = codeStyle.backgroundColor {
                output.addAttribute(.backgroundColor, value: backgroundColor, range: subrange)
            }

            output.addAttribute(MarkdownAttribute.inlineCode, value: true, range: subrange)
        }
    }
}
