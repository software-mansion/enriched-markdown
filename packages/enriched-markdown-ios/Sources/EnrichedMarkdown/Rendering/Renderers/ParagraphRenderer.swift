import UIKit

final class ParagraphRenderer: NodeRenderer {
    private let factory: RendererFactory
    private let config: MarkdownStyleConfig

    init(factory: RendererFactory, config: MarkdownStyleConfig) {
        self.factory = factory
        self.config = config
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let isTopLevel = context.currentBlockType == .none
        let paragraphStyle = config.paragraph

        if isTopLevel {
            let font = paragraphStyle.font ?? UIFont.preferredFont(forTextStyle: .body)
            let color = paragraphStyle.foregroundColor ?? UIColor.label
            context.setBlockStyle(font: font, color: color)
        }

        let start = output.length
        let shouldApplyMargin = context.currentBlockType == .none || context.currentBlockType == .paragraph
        let isBlockImage = node.children.count == 1 && node.children[0].type == .image
        let overrides = isBlockImage
            ? BlockMargins(marginTop: config.image.marginTop, marginBottom: config.image.marginBottom)
            : context.pluginBlockMargins ?? BlockMargins()
        let marginTop = overrides.marginTop ?? paragraphStyle.marginTop ?? 0
        let marginBottom = overrides.marginBottom ?? paragraphStyle.marginBottom
        var contentStart = start

        if shouldApplyMargin, start == 0, marginTop > 0 {
            let offset = ParagraphStyleHelpers.applyBlockSpacingBefore(
                to: output,
                at: 0,
                marginTop: marginTop
            )
            contentStart += offset
        }

        if isBlockImage {
            context.rendersBlockImage = true
        }

        if isTopLevel {
            factory.renderChildren(of: node, into: output, context: context)
            context.clearBlockStyle()
        } else {
            factory.renderChildren(of: node, into: output, context: context)
            if context.currentBlockType == .blockquote {
                ParagraphStyleHelpers.ensureTrailingNewline(in: output)
            }
        }

        context.rendersBlockImage = false

        guard output.length > start else { return }

        let range = NSRange(location: start, length: output.length - start)

        if !isBlockImage, let lineHeight = paragraphStyle.lineHeight {
            ParagraphStyleHelpers.applyBlockLineHeight(to: output, range: range, lineHeight: lineHeight)
        }

        if let alignment = paragraphStyle.textAlignment {
            ParagraphStyleHelpers.applyTextAlignment(to: output, range: range, alignment: alignment)
        }

        var spacingStart = start
        if shouldApplyMargin, contentStart != 0 {
            spacingStart += ParagraphStyleHelpers.applyParagraphSpacingBefore(
                to: output,
                range: range,
                marginTop: marginTop
            )
        }

        if shouldApplyMargin, let marginBottom {
            ParagraphStyleHelpers.applyParagraphSpacingAfter(
                to: output,
                at: spacingStart,
                marginBottom: marginBottom
            )
        }
    }
}
