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
        let drawnStyle = InlineBackground.Style(style)

        let linkValue: Any = URL(string: url) ?? url
        output.addAttribute(.link, value: linkValue, range: range)

        output.enumerateAttributes(in: range, options: []) { attributes, subrange, _ in
            if let color = style.foregroundColor {
                output.addAttribute(.foregroundColor, value: color, range: subrange)
                output.addAttribute(.underlineColor, value: color, range: subrange)
            }
            output.addAttribute(.underlineStyle, value: underlineStyle, range: subrange)

            let isInlineCode = attributes[MarkdownAttribute.inlineCode] != nil
            if let drawnStyle {
                let existing = attributes[.backgroundColor] as? UIColor
                let kept = (isInlineCode || drawnStyle.fillColor == nil) ? existing : nil
                output.addAttribute(
                    MarkdownAttribute.inlineBackground,
                    value: InlineBackground(style: drawnStyle, linkStart: start, underlay: kept),
                    range: subrange
                )
                output.removeAttribute(.backgroundColor, range: subrange)
                if let width = drawnStyle.border?.width,
                   let image = attributes[.attachment] as? MarkdownImageAttachment, image.isInline {
                    image.padding = width
                }
            } else if let fill = style.backgroundColor, !isInlineCode {
                output.addAttribute(.backgroundColor, value: fill, range: subrange)
            }
        }
    }
}
