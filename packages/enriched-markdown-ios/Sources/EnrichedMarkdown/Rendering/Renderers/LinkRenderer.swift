import UIKit

final class LinkRenderer: NodeRenderer {
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

        let url = node.attribute("url") ?? ""
        let linkStyle = config.link
        let linkColor = linkStyle.foregroundColor
        let underline = linkStyle.underline ?? true
        let underlineStyle = underline ? NSUnderlineStyle.single.rawValue : 0

        let linkValue: Any = URL(string: url) ?? url
        output.addAttribute(.link, value: linkValue, range: range)

        output.enumerateAttributes(in: range, options: []) { _, subrange, _ in
            if let linkColor {
                output.addAttribute(.foregroundColor, value: linkColor, range: subrange)
                output.addAttribute(.underlineColor, value: linkColor, range: subrange)
            }
            output.addAttribute(.underlineStyle, value: underlineStyle, range: subrange)
        }
    }
}
