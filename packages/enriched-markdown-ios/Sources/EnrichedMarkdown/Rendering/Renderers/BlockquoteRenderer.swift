import UIKit

/// Renders `> quote` blocks and, for `.admonition` nodes, GitHub alerts: the
/// same quote with a tinted bar and a bold tinted title paragraph whose head
/// indent reserves a column for the icon the decoration view draws.
final class BlockquoteRenderer: NodeRenderer {
    private let factory: RendererFactory
    private let config: MarkdownStyleConfig

    init(factory: RendererFactory, config: MarkdownStyleConfig) {
        self.factory = factory
        self.config = config
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let admonition = Self.admonitionType(of: node)
        context.enterBlockquote(admonition: admonition)
        let levels = context.blockquoteLevels
        let depth = levels.count - 1

        let blockStyle = config.blockquote
        let font = blockStyle.font ?? UIFont.preferredFont(forTextStyle: .body)
        let color = blockStyle.foregroundColor ?? UIColor.label
        context.setBlockStyle(font: font, color: color, blockType: .blockquote)

        ParagraphStyleHelpers.ensureStartingOnNewLine(in: output)
        let start = output.length
        if let admonition {
            appendHeader(for: admonition, font: font, to: output)
        }
        factory.renderChildren(of: node, into: output, context: context)
        context.clearBlockStyle()
        context.exitBlockquote()

        guard output.length > start else { return }

        applyStylingAndSpacing(to: output, start: start, end: output.length, levels: levels)
    }

    private static func admonitionType(of node: MarkdownASTNode) -> AdmonitionType? {
        guard node.type == .admonition else { return nil }
        return AdmonitionType(rawValue: node.attribute("admonitionType") ?? "") ?? .note
    }

    private func appendHeader(for type: AdmonitionType, font: UIFont, to output: NSMutableAttributedString) {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = AdmonitionHeader.bodyGap(for: font)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: FontHelpers.ensureBold(font) ?? font,
            .foregroundColor: config.blockquote.admonitionTint(for: type),
            .paragraphStyle: style,
            MarkdownAttribute.admonitionHeader: type.rawValue
        ]
        output.append(NSAttributedString(string: type.title + "\n", attributes: attributes))
    }

    private func applyStylingAndSpacing(
        to output: NSMutableAttributedString,
        start: Int,
        end: Int,
        levels: [AdmonitionType?]
    ) {
        let depth = levels.count - 1
        var contentStart = start
        if depth == 0 {
            contentStart += ParagraphStyleHelpers.applyBlockSpacingBefore(
                to: output,
                at: start,
                marginTop: config.blockquote.marginTop ?? 0
            )
        }

        let range = NSRange(location: contentStart, length: end - start)
        applyBlockAttributes(to: output, range: range, levels: levels)
        applyParagraphLayout(to: output, range: range, depth: depth)

        if depth == 0, let marginBottom = config.blockquote.marginBottom, marginBottom > 0 {
            ParagraphStyleHelpers.applyBlockSpacingAfter(to: output, marginBottom: marginBottom)
        }
    }

    /// Depth, background, and bar colors on every run the quote owns; runs a
    /// nested quote already claimed keep theirs.
    private func applyBlockAttributes(
        to output: NSMutableAttributedString,
        range: NSRange,
        levels: [AdmonitionType?]
    ) {
        let blockStyle = config.blockquote
        var attributes: [NSAttributedString.Key: Any] = [
            MarkdownAttribute.blockquoteDepth: levels.count - 1
        ]
        if let admonition = levels.last ?? nil {
            attributes[MarkdownAttribute.blockquoteBackgroundColor] =
                blockStyle.admonitions[admonition]?.backgroundColor ?? UIColor.clear
        } else if let backgroundColor = blockStyle.backgroundColor {
            attributes[MarkdownAttribute.blockquoteBackgroundColor] = backgroundColor
        }
        if levels.contains(where: { $0 != nil }) {
            attributes[MarkdownAttribute.blockquoteBarColors] = levels.map { level in
                level.map(blockStyle.admonitionTint(for:)) ?? blockStyle.resolvedBorderColor
            }
        }

        output.enumerateAttribute(MarkdownAttribute.blockquoteDepth, in: range, options: []) { value, subrange, _ in
            guard value == nil else { return }
            output.addAttributes(attributes, range: subrange)
        }
    }

    /// Indents the quote's own paragraphs past the bars and applies the
    /// configured line height. List items position themselves (their indent
    /// already includes the quote offset) and nested quotes are already laid
    /// out, so both are skipped.
    private func applyParagraphLayout(to output: NSMutableAttributedString, range: NSRange, depth: Int) {
        let levelSpacing = (config.blockquote.borderWidth ?? 3) + (config.blockquote.gapWidth ?? 16)
        let indent = CGFloat(depth + 1) * levelSpacing
        let string = output.string as NSString
        var location = range.location
        let end = NSMaxRange(range)

        while location < end {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            let applyRange = NSIntersectionRange(paragraphRange, range)
            guard applyRange.length > 0 else { break }
            location = NSMaxRange(applyRange)

            let attrs = output.attributes(at: applyRange.location, effectiveRange: nil)
            if attrs[MarkdownAttribute.listDepth] != nil {
                continue
            }
            if let paragraphDepth = MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.blockquoteDepth]),
               paragraphDepth > depth {
                continue
            }

            var paragraphIndent = indent
            if attrs[MarkdownAttribute.admonitionHeader] != nil, let font = attrs[.font] as? UIFont {
                paragraphIndent += AdmonitionHeader.iconColumnWidth(for: font)
            }

            let style = ParagraphStyleHelpers.getOrCreateParagraphStyle(in: output, at: applyRange.location)
            style.firstLineHeadIndent = paragraphIndent
            style.headIndent = paragraphIndent
            style.tailIndent = 0
            output.addAttribute(.paragraphStyle, value: style, range: applyRange)

            if let lineHeight = config.blockquote.lineHeight {
                ParagraphStyleHelpers.applyBlockLineHeight(to: output, range: applyRange, lineHeight: lineHeight)
            }
        }
    }
}
