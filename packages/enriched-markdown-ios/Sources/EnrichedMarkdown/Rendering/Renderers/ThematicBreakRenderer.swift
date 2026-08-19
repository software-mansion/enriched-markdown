import UIKit

final class ThematicBreakRenderer: NodeRenderer {
    private let config: MarkdownStyleConfig

    init(config: MarkdownStyleConfig) {
        self.config = config
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        if output.length > 0, !output.string.hasSuffix("\n") {
            output.append(ParagraphStyleHelpers.newline)
        }

        let style = config.thematicBreak
        let attachment = ThematicBreakAttachment()
        attachment.lineColor = style.color ?? UIColor.separator
        attachment.lineHeight = (style.height ?? 1) > 0 ? (style.height ?? 1) : 1
        attachment.marginTop = style.marginTop ?? 0
        attachment.marginBottom = style.marginBottom ?? 0

        let attributes: [NSAttributedString.Key: Any] = [
            .attachment: attachment,
            .paragraphStyle: NSParagraphStyle.default
        ]

        output.append(NSAttributedString(string: "\u{FFFC}", attributes: attributes))
        output.append(ParagraphStyleHelpers.newline)
    }
}
