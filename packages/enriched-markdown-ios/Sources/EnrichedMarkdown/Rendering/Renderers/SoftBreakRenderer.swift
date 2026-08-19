import UIKit

final class SoftBreakRenderer: NodeRenderer {
    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let space = NSAttributedString(
            string: " ",
            attributes: context.getTextAttributes()
        )
        output.append(space)
    }
}
