import UIKit

final class TextRenderer: NodeRenderer {
    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        guard !node.content.isEmpty else { return }
        var attributes = context.getTextAttributes()
        if let sourceRange = SourceOffsetAnnotator.sourceRangeValue(of: node) {
            attributes[MarkdownAttribute.sourceRange] = sourceRange
        }
        let text = NSAttributedString(string: node.content, attributes: attributes)
        output.append(text)
    }
}
