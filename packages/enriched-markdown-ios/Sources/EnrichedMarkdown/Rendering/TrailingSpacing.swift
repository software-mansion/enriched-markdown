import UIKit

struct TrailingSpacing: Hashable {
    var margin: CGFloat = 0
    var padding: CGFloat = 0

    func inset(marginEnabled: Bool) -> CGFloat {
        padding + (marginEnabled ? margin : 0)
    }

    static func read(from text: NSAttributedString) -> TrailingSpacing {
        guard text.length > 0 else { return TrailingSpacing() }
        let value = text.attribute(MarkdownAttribute.trailingSpacing, at: text.length - 1, effectiveRange: nil)
        return value as? TrailingSpacing ?? TrailingSpacing()
    }
}

extension TrailingSpacing {
    static func strip(from output: NSMutableAttributedString, codeBlockPadding: CGFloat) {
        let string = output.mutableString
        let lastVisible = string.rangeOfCharacter(from: ParagraphStyleHelpers.nonNewlines, options: .backwards)
        guard lastVisible.location != NSNotFound else { return }
        let end = NSMaxRange(lastVisible)

        var spacing = TrailingSpacing()
        let tail = NSRange(location: lastVisible.location, length: string.length - lastVisible.location)
        output.enumerateAttribute(.paragraphStyle, in: tail, options: []) { value, _, _ in
            spacing.margin = max(spacing.margin, (value as? NSParagraphStyle)?.paragraphSpacing ?? 0)
        }
        let attributes = output.attributes(at: lastVisible.location, effectiveRange: nil)
        if let rule = attributes[.attachment] as? ThematicBreakAttachment {
            spacing.margin = max(spacing.margin, rule.marginBottom)
            rule.marginBottom = 0
        }
        if MarkdownAttributeValue.boolValue(from: attributes[MarkdownAttribute.codeBlock]) {
            spacing.padding = codeBlockPadding
        }

        output.deleteCharacters(in: NSRange(location: end, length: string.length - end))
        let paragraph = string.paragraphRange(for: lastVisible)
        output.enumerateAttribute(.paragraphStyle, in: paragraph, options: []) { value, range, _ in
            guard let style = value as? NSParagraphStyle, style.paragraphSpacing != 0,
                  let zeroed = style.mutableCopy() as? NSMutableParagraphStyle
            else { return }
            zeroed.paragraphSpacing = 0
            output.addAttribute(.paragraphStyle, value: zeroed, range: range)
        }
        output.addAttribute(MarkdownAttribute.trailingSpacing, value: spacing, range: paragraph)
    }
}
