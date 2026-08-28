import UIKit

/// Renders superscript (`^text^`) and subscript (`~text~`) spans by shrinking
/// the font and shifting the baseline relative to the surrounding text size.
///
/// The tree walk only marks the affected ranges; `applyShifts(to:config:)`
/// performs the actual font scaling and baseline offsets after block
/// processing, so the shift stacks on top of the line-height centering offset
/// that `ParagraphStyleHelpers` gives the surrounding text (that pass skips
/// runs which already carry a baseline offset).
final class BaselineShiftRenderer: NodeRenderer {
    enum Kind {
        case superscript
        case `subscript`
    }

    static let defaultFontScale: CGFloat = 0.75
    static let defaultSuperscriptBaselineOffsetScale: CGFloat = 0.35
    static let defaultSubscriptBaselineOffsetScale: CGFloat = 0.20

    private let factory: RendererFactory
    private let attributeKey: NSAttributedString.Key

    init(factory: RendererFactory, kind: Kind) {
        self.factory = factory
        attributeKey = kind == .superscript ? MarkdownAttribute.superscript : MarkdownAttribute.subscript
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let start = output.length
        factory.renderChildren(of: node, into: output, context: context)

        let range = RenderContext.rangeForRenderedContent(in: output, start: start)
        guard range.length > 0 else { return }

        output.addAttribute(attributeKey, value: true, range: range)
    }

    /// Call exactly once per assembled attributed string, after all block
    /// styling (line heights, margins) is in place.
    static func applyShifts(to output: NSMutableAttributedString, config: MarkdownStyleConfig) {
        applyShift(
            to: output,
            key: MarkdownAttribute.superscript,
            fontScale: config.superscript.fontScale ?? defaultFontScale,
            baselineOffsetScale: config.superscript.baselineOffsetScale
                ?? defaultSuperscriptBaselineOffsetScale
        )
        applyShift(
            to: output,
            key: MarkdownAttribute.subscript,
            fontScale: config.subscript.fontScale ?? defaultFontScale,
            baselineOffsetScale: -(config.subscript.baselineOffsetScale
                ?? defaultSubscriptBaselineOffsetScale)
        )
    }

    private static func applyShift(
        to output: NSMutableAttributedString,
        key: NSAttributedString.Key,
        fontScale: CGFloat,
        baselineOffsetScale: CGFloat
    ) {
        let fullRange = NSRange(location: 0, length: output.length)
        output.enumerateAttribute(key, in: fullRange, options: []) { value, range, _ in
            guard MarkdownAttributeValue.boolValue(from: value) else { return }

            output.enumerateAttributes(in: range, options: []) { attributes, subrange, _ in
                guard let font = attributes[.font] as? UIFont else { return }

                output.addAttribute(.font, value: font.withSize(font.pointSize * fontScale), range: subrange)

                let currentOffset = (attributes[.baselineOffset] as? NSNumber)?.doubleValue ?? 0
                output.addAttribute(
                    .baselineOffset,
                    value: currentOffset + font.pointSize * baselineOffsetScale,
                    range: subrange
                )
            }
        }
    }
}
