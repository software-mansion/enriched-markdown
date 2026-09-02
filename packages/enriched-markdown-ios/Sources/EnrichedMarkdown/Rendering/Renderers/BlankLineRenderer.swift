import UIKit

// Renders a run of consecutive blank lines emitted when preserveBlankLines is
// enabled. Each blank line in the source is drawn as one empty line, using the
// paragraph font, line height and alignment so its vertical rhythm matches the
// surrounding paragraphs. Any extra block spacing is left to the caller to
// configure.
final class BlankLineRenderer: NodeRenderer {
    private let config: MarkdownStyleConfig

    init(config: MarkdownStyleConfig) {
        self.config = config
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let count = Int(node.attribute("count") ?? "0") ?? 0
        guard count > 0 else { return }

        if output.length > 0, !output.string.hasSuffix("\n") {
            output.append(ParagraphStyleHelpers.newline)
        }

        let paragraph = config.paragraph
        let font = paragraph.font ?? UIFont.preferredFont(forTextStyle: .body)

        let start = output.length
        output.append(NSAttributedString(string: String(repeating: "\n", count: count), attributes: [.font: font]))
        let range = NSRange(location: start, length: output.length - start)

        if let lineHeight = paragraph.lineHeight {
            ParagraphStyleHelpers.applyBlockLineHeight(to: output, range: range, lineHeight: lineHeight)
        }
        if let alignment = paragraph.textAlignment {
            ParagraphStyleHelpers.applyTextAlignment(to: output, range: range, alignment: alignment)
        }
    }
}
