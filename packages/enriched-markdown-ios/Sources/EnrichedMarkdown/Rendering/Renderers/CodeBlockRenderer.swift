import UIKit

final class CodeBlockRenderer: NodeRenderer {
    private let factory: RendererFactory
    private let config: MarkdownStyleConfiguration
    private let plugins: [any MarkdownRenderPlugin]
    private let layout: MarkdownCodeBlockLayout

    init(
        factory: RendererFactory,
        config: MarkdownStyleConfiguration,
        plugins: [any MarkdownRenderPlugin],
        layout: MarkdownCodeBlockLayout = .wrapping
    ) {
        self.factory = factory
        self.config = config
        self.plugins = plugins
        self.layout = layout
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        switch layout {
        case .wrapping:
            renderWrapping(node: node, into: output, context: context)
        case .scrollable:
            renderScrollable(node: node, into: output)
        }
    }

    /// The code lives in its own string, so the plugins color that one.
    private func renderScrollable(node: MarkdownASTNode, into output: NSMutableAttributedString) {
        let style = CodeBlockAttachmentStyle(config: config)
        var code = node.flattenedText()
        while code.hasSuffix("\n") {
            code.removeLast()
        }
        let language = node.attribute("language").flatMap { $0.isEmpty ? nil : $0 }
        let attributedCode = CodeBlockAttachment.attributedCode(code, style: style)
        if let language {
            let range = NSRange(location: 0, length: attributedCode.length)
            for plugin in plugins {
                plugin.styleCodeBlock(in: attributedCode, range: range, language: language, config: config)
            }
        }
        let attachment = CodeBlockAttachment(
            code: code,
            language: language,
            fenceCharacter: node.attribute("fenceChar") ?? "`",
            attributedCode: attributedCode,
            style: style
        )

        ParagraphStyleHelpers.ensureStartingOnNewLine(in: output)
        if style.marginTop > 0 {
            _ = ParagraphStyleHelpers.applyBlockSpacingBefore(
                to: output,
                at: output.length,
                marginTop: style.marginTop
            )
        }
        var attributes: [NSAttributedString.Key: Any] = [.attachment: attachment]
        SourceOffsetAnnotator.tagSourceRange(in: &attributes, of: node)
        output.append(NSAttributedString(string: "\u{FFFC}", attributes: attributes))
        output.append(NSAttributedString(string: "\n"))
        ParagraphStyleHelpers.applyBlockSpacingAfter(to: output, marginBottom: style.marginBottom)
    }

    private func renderWrapping(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let blockStyle = config.codeBlock
        let font = blockStyle.font ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        let color = blockStyle.foregroundColor ?? UIColor.label
        context.setBlockStyle(font: font, color: color, blockType: .codeBlock)

        let padding = blockStyle.padding ?? 0
        let lineHeight = blockStyle.lineHeight ?? 0
        let marginTop = blockStyle.marginTop ?? 0
        let marginBottom = blockStyle.marginBottom ?? 0

        ParagraphStyleHelpers.ensureStartingOnNewLine(in: output)

        var blockStart = output.length
        blockStart += ParagraphStyleHelpers.applyBlockSpacingBefore(
            to: output,
            at: blockStart,
            marginTop: marginTop
        )

        if padding > 0 {
            let topSpacerLocation = output.length
            output.append(ParagraphStyleHelpers.newline)
            let topSpacerStyle = ParagraphStyleHelpers.spacerParagraphStyle(height: padding)
            topSpacerStyle.baseWritingDirection = .leftToRight
            output.addAttribute(
                .paragraphStyle,
                value: topSpacerStyle,
                range: NSRange(location: topSpacerLocation, length: 1)
            )
        }

        let contentStart = output.length
        factory.renderChildren(of: node, into: output, context: context)
        context.clearBlockStyle()

        guard output.length > contentStart else { return }

        let contentRange = NSRange(location: contentStart, length: output.length - contentStart)
        let codeFont = blockStyle.font ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)

        if let codeColor = blockStyle.foregroundColor {
            output.addAttributes(
                [.font: codeFont, .foregroundColor: codeColor],
                range: contentRange
            )
        } else {
            output.addAttribute(.font, value: codeFont, range: contentRange)
        }

        let baseStyle = ParagraphStyleHelpers.getOrCreateParagraphStyle(in: output, at: contentStart)
        baseStyle.baseWritingDirection = .leftToRight
        baseStyle.alignment = blockStyle.textAlignment ?? .left
        baseStyle.firstLineHeadIndent = padding
        baseStyle.headIndent = padding
        baseStyle.tailIndent = -padding
        output.addAttribute(.paragraphStyle, value: baseStyle, range: contentRange)

        if lineHeight > 0 {
            ParagraphStyleHelpers.applyBlockLineHeight(to: output, range: contentRange, lineHeight: lineHeight)
        }

        if padding > 0 {
            let bottomSpacerLocation = output.length
            output.append(ParagraphStyleHelpers.newline)
            let bottomSpacerStyle = ParagraphStyleHelpers.spacerParagraphStyle(height: padding)
            bottomSpacerStyle.baseWritingDirection = .leftToRight
            output.addAttribute(
                .paragraphStyle,
                value: bottomSpacerStyle,
                range: NSRange(location: bottomSpacerLocation, length: 1)
            )
        }

        let backgroundRange = NSRange(location: blockStart, length: output.length - blockStart)
        output.addAttribute(MarkdownAttribute.codeBlock, value: true, range: backgroundRange)

        if marginBottom > 0 {
            ParagraphStyleHelpers.applyBlockSpacingAfter(to: output, marginBottom: marginBottom)
        }

        guard let language = node.attribute("language") else { return }
        output.addAttribute(MarkdownAttribute.codeBlockLanguage, value: language, range: backgroundRange)
        for plugin in plugins {
            plugin.styleCodeBlock(in: output, range: contentRange, language: language, config: config)
        }
    }
}
