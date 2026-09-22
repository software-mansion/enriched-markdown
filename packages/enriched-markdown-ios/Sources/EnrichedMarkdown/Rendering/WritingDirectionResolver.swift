import UIKit

/// Stamps `baseWritingDirection` on every paragraph after a render, as the
/// React Native package does: the block chrome (blockquote bars, list
/// markers, checkboxes, admonition icons) and the task-list hit test read it
/// from the paragraph style, where `.natural` would mean the app's interface
/// direction rather than the paragraph's. Code blocks keep the
/// `.leftToRight` their renderer sets.
enum WritingDirectionResolver {
    /// Hebrew through Arabic Extended-B, plus the Hebrew and Arabic
    /// presentation forms.
    private static let rightToLeftScalars: [ClosedRange<UInt32>] = [0x0590...0x08FF, 0xFB1D...0xFDFF, 0xFE70...0xFEFF]
    private static let letters = CharacterSet.letters

    /// Direction of the first letter in `text`, or `.natural` when it has none.
    static func firstStrongDirection(of text: String) -> NSWritingDirection {
        let string = text as NSString
        return firstStrongDirection(in: string, range: NSRange(location: 0, length: string.length))
    }

    /// The same over one paragraph, in place. A letter beyond the BMP counts
    /// by its lead surrogate: left-to-right, as the table has no ranges there.
    private static func firstStrongDirection(in string: NSString, range: NSRange) -> NSWritingDirection {
        let letter = string.rangeOfCharacter(from: letters, range: range)
        guard letter.location != NSNotFound else { return .natural }
        let value = UInt32(string.character(at: letter.location))
        return rightToLeftScalars.contains { $0.contains(value) } ? .rightToLeft : .leftToRight
    }

    /// `layoutDirection` is what a `.firstStrong` paragraph with no strong
    /// character falls back to.
    static func apply(
        _ mode: MarkdownWritingDirection,
        layoutDirection: UIUserInterfaceLayoutDirection,
        to output: NSMutableAttributedString
    ) {
        let string = output.string as NSString
        let direction: ([NSAttributedString.Key: Any], NSRange) -> NSWritingDirection
        switch mode {
        case .natural:
            return
        case .leftToRight:
            direction = { _, _ in .leftToRight }
        case .rightToLeft:
            direction = { _, _ in .rightToLeft }
        case .firstStrong:
            let fallback: NSWritingDirection = layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
            direction = { attrs, paragraphRange in
                let detected = attrs[MarkdownAttribute.admonitionHeader] == nil
                    ? firstStrongDirection(in: string, range: paragraphRange)
                    : bodyDirection(afterTitle: paragraphRange, of: string, in: output)
                return detected == .natural ? fallback : detected
            }
        }

        for paragraphRange in paragraphRanges(in: string) {
            let attrs = output.attributes(at: paragraphRange.location, effectiveRange: nil)
            guard !MarkdownAttributeValue.boolValue(from: attrs[MarkdownAttribute.codeBlock]) else { continue }
            stamp(direction(attrs, paragraphRange), on: paragraphRange, in: output)
        }
    }

    /// An admonition title ("Note") is the renderer's text, not the author's,
    /// so it takes the direction of the body it introduces: the first strong
    /// character in the quote paragraphs after it, nested titles excluded.
    private static func bodyDirection(
        afterTitle titleRange: NSRange,
        of string: NSString,
        in output: NSAttributedString
    ) -> NSWritingDirection {
        let titleAttrs = output.attributes(at: titleRange.location, effectiveRange: nil)
        guard let titleDepth = MarkdownAttributeValue.intValue(from: titleAttrs[MarkdownAttribute.blockquoteDepth]) else {
            return .natural
        }

        for paragraphRange in paragraphRanges(in: string, from: NSMaxRange(titleRange)) {
            let attrs = output.attributes(at: paragraphRange.location, effectiveRange: nil)
            guard let depth = MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.blockquoteDepth]),
                  depth >= titleDepth
            else { break }
            guard attrs[MarkdownAttribute.admonitionHeader] == nil else { continue }
            let direction = firstStrongDirection(in: string, range: paragraphRange)
            if direction != .natural {
                return direction
            }
        }
        return .natural
    }

    /// Paragraph ranges, terminators included, from `start` to the end.
    private static func paragraphRanges(in string: NSString, from start: Int = 0) -> some Sequence<NSRange> {
        sequence(state: start) { (position: inout Int) -> NSRange? in
            guard position < string.length else { return nil }
            let range = string.paragraphRange(for: NSRange(location: position, length: 0))
            position = NSMaxRange(range)
            return range
        }
    }

    private static func stamp(_ direction: NSWritingDirection, on range: NSRange, in output: NSMutableAttributedString) {
        output.enumerateAttribute(.paragraphStyle, in: range) { value, runRange, _ in
            let style = value as? NSParagraphStyle
            guard style?.baseWritingDirection != direction else { return }
            let updated = (style?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            updated.baseWritingDirection = direction
            output.addAttribute(.paragraphStyle, value: updated, range: runRange)
        }
    }
}
