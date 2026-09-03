import UIKit

final class ImageRenderer: NodeRenderer {
    private let config: MarkdownStyleConfig
    private let requestHeaders: [String: String]

    init(config: MarkdownStyleConfig, requestHeaders: [String: String] = [:]) {
        self.config = config
        self.requestHeaders = requestHeaders
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        guard let url = node.attribute("url"), !url.isEmpty else { return }

        let isInline = !context.rendersBlockImage && isInlineImage(in: output)
        let altText = node.flattenedText().trimmingCharacters(in: .whitespacesAndNewlines)
        let attachment = MarkdownImageAttachment.attachment(
            for: url,
            config: config,
            isInline: isInline,
            altText: altText,
            requestHeaders: requestHeaders
        )

        var attributes: [NSAttributedString.Key: Any] = [.attachment: attachment]
        SourceOffsetAnnotator.tagSourceRange(in: &attributes, of: node)
        output.append(NSAttributedString(string: "\u{FFFC}", attributes: attributes))
    }

    private func isInlineImage(in output: NSAttributedString) -> Bool {
        guard output.length > 0 else { return false }
        let lastChar = (output.string as NSString).character(at: output.length - 1)
        return lastChar != 10 && lastChar != 0x200B
    }
}
