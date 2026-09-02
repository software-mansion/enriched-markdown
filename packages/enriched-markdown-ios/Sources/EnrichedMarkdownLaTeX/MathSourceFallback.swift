import EnrichedMarkdown
import UIKit

/// Renders a math node as its delimited source text — the typeset-failure
/// path, so math is never silently dropped.
final class MathSourceFallbackRenderer: NodeRenderer {
    func render(
        node: MarkdownASTNode,
        into output: NSMutableAttributedString,
        context: RenderContext
    ) {
        let latex = node.latexSourceText()
        guard !latex.isEmpty else { return }

        let delimiter = node.type == .latexMathDisplay ? "$$" : "$"
        output.append(NSAttributedString(
            string: delimiter + latex + delimiter,
            attributes: context.getTextAttributes()
        ))
    }
}

extension MarkdownASTNode {
    /// Concatenated text children; any break nodes map to newlines, which
    /// TeX treats the same as the spaces the core usually flattens them to.
    func latexSourceText() -> String {
        var buffer = ""
        appendLatexSource(to: &buffer)
        return buffer
    }

    private func appendLatexSource(to buffer: inout String) {
        switch type {
        case .softBreak, .lineBreak:
            buffer.append("\n")
        default:
            if !content.isEmpty {
                buffer.append(content)
            }
        }
        for child in children {
            child.appendLatexSource(to: &buffer)
        }
    }
}
