import UIKit

// Renders a run of consecutive blank lines emitted when preserveBlankLines is
// enabled. Each blank line in the source is drawn as one empty line, so the
// rendered text keeps the exact line count that was typed (e.g. in a text
// editor). Any extra vertical spacing comes from the surrounding paragraph style
// and is left to the caller to configure.
final class BlankLineRenderer: NodeRenderer {
    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let count = Int(node.attribute("count") ?? "0") ?? 0
        guard count > 0 else { return }

        if output.length > 0, !output.string.hasSuffix("\n") {
            output.append(ParagraphStyleHelpers.newline)
        }

        let blanks = String(repeating: "\n", count: count)
        output.append(NSAttributedString(string: blanks, attributes: context.getTextAttributes()))
    }
}
