import UIKit

final class TextRenderer: NodeRenderer {
    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        guard !node.content.isEmpty else { return }
        let text = NSAttributedString(string: node.content, attributes: context.getTextAttributes())
        output.append(text)
    }
}
