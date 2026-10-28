import UIKit

final class LinkRenderer: NodeRenderer {
    private let factory: RendererFactory
    private let styles: LinkStyleResolver<ElementStyle>

    init(factory: RendererFactory, config: MarkdownStyleConfiguration) {
        self.factory = factory
        styles = LinkStyleResolver(config: config)
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let start = output.length
        factory.renderChildren(of: node, into: output, context: context)

        let range = RenderContext.rangeForRenderedContent(in: output, start: start)
        guard range.length > 0 else { return }

        let url = node.attribute("url") ?? ""
        let style = styles.resolve(url)
        let underlineStyle = (style.underline ?? true) ? NSUnderlineStyle.single.rawValue : 0
        let drawnBackground = InlineBackground(style: style)

        let linkValue: Any = URL(string: url) ?? url
        output.addAttribute(.link, value: linkValue, range: range)

        output.enumerateAttributes(in: range, options: []) { attributes, subrange, _ in
            if let color = style.foregroundColor {
                output.addAttribute(.foregroundColor, value: color, range: subrange)
                output.addAttribute(.underlineColor, value: color, range: subrange)
            }
            output.addAttribute(.underlineStyle, value: underlineStyle, range: subrange)

            let isInlineCode = attributes[MarkdownAttribute.inlineCode] != nil
            if let drawnBackground {
                output.addAttribute(MarkdownAttribute.inlineBackground, value: drawnBackground, range: subrange)
                if drawnBackground.fillColor != nil, !isInlineCode, attributes[.backgroundColor] != nil {
                    output.removeAttribute(.backgroundColor, range: subrange)
                }
            } else if let fill = style.backgroundColor, !isInlineCode {
                output.addAttribute(.backgroundColor, value: fill, range: subrange)
            }
        }
    }
}
