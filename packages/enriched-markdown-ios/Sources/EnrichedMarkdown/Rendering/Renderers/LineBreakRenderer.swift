import UIKit

final class LineBreakRenderer: NodeRenderer {
    private static let lineSeparator = "\u{2028}"

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let lineBreak = NSAttributedString(
            string: Self.lineSeparator,
            attributes: context.getTextAttributes()
        )
        output.append(lineBreak)
    }
}
