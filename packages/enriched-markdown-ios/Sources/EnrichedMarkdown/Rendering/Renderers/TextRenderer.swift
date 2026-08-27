import UIKit

final class TextRenderer: NodeRenderer {
    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        guard !node.content.isEmpty else { return }
        var attributes = context.getTextAttributes()
        SourceOffsetAnnotator.tagSourceRange(in: &attributes, of: node)
        let text = NSAttributedString(string: node.content, attributes: attributes)
        output.append(text)
    }
}
