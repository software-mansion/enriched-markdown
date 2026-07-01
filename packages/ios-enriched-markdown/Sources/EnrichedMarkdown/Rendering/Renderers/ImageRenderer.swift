import UIKit

final class ImageRenderer: NodeRenderer {
    private let config: MarkdownStyleConfig

    init(config: MarkdownStyleConfig) {
        self.config = config
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        guard let url = node.attribute("url"), !url.isEmpty else { return }

        let isInline = !context.rendersBlockImage && isInlineImage(in: output)
        let altText = extractText(from: node)
        let attachment = MarkdownImageAttachment.attachment(
            for: url,
            config: config,
            isInline: isInline,
            altText: altText
        )

        let imageString = NSAttributedString(attachment: attachment)
        output.append(imageString)
    }

    private func isInlineImage(in output: NSAttributedString) -> Bool {
        guard output.length > 0 else { return false }
        let lastChar = (output.string as NSString).character(at: output.length - 1)
        return lastChar != 10 && lastChar != 0x200B
    }

    private func extractText(from node: MarkdownASTNode) -> String {
        var buffer = ""
        appendText(from: node, to: &buffer)
        return buffer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func appendText(from node: MarkdownASTNode, to buffer: inout String) {
        if !node.content.isEmpty {
            buffer.append(node.content)
        }
        for child in node.children {
            appendText(from: child, to: &buffer)
        }
    }
}
