import UIKit

protocol NodeRenderer: AnyObject {
    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext)
}

final class ChildrenOnlyRenderer: NodeRenderer {
    private let factory: RendererFactory

    init(factory: RendererFactory) {
        self.factory = factory
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        factory.renderChildren(of: node, into: output, context: context)
    }
}
