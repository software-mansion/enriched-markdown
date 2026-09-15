import UIKit

/// Tags `||spoiler||` text. `SpoilerConcealment` hides it in a post-pass and
/// the text view draws the overlay.
final class SpoilerRenderer: NodeRenderer {
    private let factory: RendererFactory

    init(factory: RendererFactory) {
        self.factory = factory
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let start = output.length
        factory.renderChildren(of: node, into: output, context: context)

        let range = RenderContext.rangeForRenderedContent(in: output, start: start)
        guard range.length > 0 else { return }
        output.addAttribute(MarkdownAttribute.spoiler, value: true, range: range)
    }
}
