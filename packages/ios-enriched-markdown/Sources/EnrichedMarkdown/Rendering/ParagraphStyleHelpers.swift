import CoreText
import UIKit

enum ParagraphStyleHelpers {
    static let newline = NSAttributedString(string: "\n")

    @discardableResult
    static func applyParagraphSpacingBefore(
        to output: NSMutableAttributedString,
        range: NSRange,
        marginTop: CGFloat
    ) -> Int {
        guard range.location > 0, marginTop > 0 else { return 0 }

        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = marginTop

        let spacer = NSMutableAttributedString(attributedString: newline)
        spacer.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: 1))
        output.insert(spacer, at: range.location)
        return 1
    }

    @discardableResult
    static func applyBlockSpacingBefore(
        to output: NSMutableAttributedString,
        at insertionPoint: Int,
        marginTop: CGFloat
    ) -> Int {
        guard marginTop > 0 else { return 0 }

        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = marginTop

        let spacer = NSMutableAttributedString(attributedString: newline)
        spacer.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: 1))
        output.insert(spacer, at: insertionPoint)
        return 1
    }

    /// Appends a trailing newline and sets `paragraphSpacing` on the block paragraph.
    /// UITextView lays out `paragraphSpacing` reliably; a dedicated spacer line with only
    /// `minimumLineHeight`/`maximumLineHeight` is often collapsed to zero height.
    static func applyParagraphSpacingAfter(
        to output: NSMutableAttributedString,
        at contentStart: Int,
        marginBottom: CGFloat
    ) {
        guard contentStart <= output.length else { return }

        output.append(newline)

        let style = getOrCreateParagraphStyle(in: output, at: contentStart)
        style.paragraphSpacing = marginBottom

        let range = NSRange(location: contentStart, length: output.length - contentStart)
        output.addAttribute(.paragraphStyle, value: style, range: range)
    }

    static func applyLineHeight(
        to output: NSMutableAttributedString,
        range: NSRange,
        lineHeight: CGFloat
    ) {
        guard lineHeight > 0, range.length > 0 else { return }

        let roundedLineHeight = ceil(lineHeight)
        let style = getOrCreateParagraphStyle(in: output, at: range.location)
        style.lineSpacing = 0
        style.minimumLineHeight = roundedLineHeight
        style.maximumLineHeight = roundedLineHeight
        output.addAttribute(.paragraphStyle, value: style, range: range)
    }

    static func applyBaselineOffset(
        to output: NSMutableAttributedString,
        range: NSRange
    ) {
        guard range.length > 0 else { return }

        var maximumLineHeight: CGFloat = 0
        output.enumerateAttribute(.paragraphStyle, in: range) { value, _, _ in
            guard let paragraphStyle = value as? NSParagraphStyle else { return }
            maximumLineHeight = max(paragraphStyle.maximumLineHeight, maximumLineHeight)
        }
        guard maximumLineHeight > 0 else { return }

        output.enumerateAttribute(.font, in: range) { value, subrange, _ in
            guard let font = value as? UIFont else { return }
            guard output.attribute(.baselineOffset, at: subrange.location, effectiveRange: nil) == nil else {
                return
            }

            let naturalHeight = typographicLineHeight(for: font)
            guard naturalHeight > 0, maximumLineHeight >= naturalHeight else { return }

            let leading = maximumLineHeight - naturalHeight
            let baselineOffset = ceil(leading / 2)
            output.addAttribute(.baselineOffset, value: baselineOffset, range: subrange)
        }
    }

    static func applyBlockLineHeight(
        to output: NSMutableAttributedString,
        range: NSRange,
        lineHeight: CGFloat
    ) {
        applyLineHeight(to: output, range: range, lineHeight: lineHeight)
        applyBaselineOffset(to: output, range: range)
    }

    static func applyTextAlignment(
        to output: NSMutableAttributedString,
        range: NSRange,
        alignment: NSTextAlignment
    ) {
        guard range.length > 0 else { return }

        output.enumerateAttribute(
            .paragraphStyle,
            in: range,
            options: []
        ) { value, subrange, _ in
            let paragraphStyle: NSMutableParagraphStyle
            if let existing = value as? NSParagraphStyle,
               let mutable = existing.mutableCopy() as? NSMutableParagraphStyle {
                paragraphStyle = mutable
            } else {
                paragraphStyle = NSMutableParagraphStyle()
            }
            paragraphStyle.alignment = alignment
            output.addAttribute(.paragraphStyle, value: paragraphStyle, range: subrange)
        }
    }

    static func getOrCreateParagraphStyle(
        in output: NSMutableAttributedString,
        at index: Int
    ) -> NSMutableParagraphStyle {
        if let existing = output.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle,
           let mutable = existing.mutableCopy() as? NSMutableParagraphStyle {
            return mutable
        }
        return NSMutableParagraphStyle()
    }

    static func applyHeadIndent(
        to output: NSMutableAttributedString,
        range: NSRange,
        indent: CGFloat
    ) {
        guard range.length > 0 else { return }

        output.enumerateAttribute(
            .paragraphStyle,
            in: range,
            options: []
        ) { value, subrange, _ in
            let paragraphStyle: NSMutableParagraphStyle
            if let existing = value as? NSParagraphStyle,
               let mutable = existing.mutableCopy() as? NSMutableParagraphStyle {
                paragraphStyle = mutable
            } else {
                paragraphStyle = NSMutableParagraphStyle()
            }
            paragraphStyle.firstLineHeadIndent = indent
            paragraphStyle.headIndent = indent
            output.addAttribute(.paragraphStyle, value: paragraphStyle, range: subrange)
        }
    }

    static func applyTextLists(
        to output: NSMutableAttributedString,
        range: NSRange,
        lists: [NSTextList]
    ) {
        guard range.length > 0 else { return }

        output.enumerateAttribute(
            .paragraphStyle,
            in: range,
            options: []
        ) { value, subrange, _ in
            let paragraphStyle: NSMutableParagraphStyle
            if let existing = value as? NSParagraphStyle,
               let mutable = existing.mutableCopy() as? NSMutableParagraphStyle {
                paragraphStyle = mutable
            } else {
                paragraphStyle = NSMutableParagraphStyle()
            }
            paragraphStyle.textLists = lists
            output.addAttribute(.paragraphStyle, value: paragraphStyle, range: subrange)
        }
    }

    static func spacerParagraphStyle(height: CGFloat, spacing: CGFloat = 0) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = height
        style.maximumLineHeight = height
        style.paragraphSpacing = spacing
        return style
    }

    static func ensureTrailingNewline(in output: NSMutableAttributedString) {
        guard output.length > 0, !output.string.hasSuffix("\n") else { return }
        output.append(newline)
    }

    static func ensureStartingOnNewLine(in output: NSMutableAttributedString) {
        guard output.length > 0, !output.string.hasSuffix("\n") else { return }
        output.append(newline)
    }

    static func applyBlockSpacingAfter(
        to output: NSMutableAttributedString,
        marginBottom: CGFloat
    ) {
        guard marginBottom > 0, output.length > 0 else { return }

        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = 1
        style.maximumLineHeight = 1
        style.paragraphSpacing = marginBottom

        let spacer = NSMutableAttributedString(attributedString: newline)
        spacer.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: 1))
        output.append(spacer)
    }

    /// Matches Android `LineHeightSpan` natural height: `(-ascent) + descent`.
    private static func typographicLineHeight(for font: UIFont) -> CGFloat {
        let ctFont = font as CTFont
        return CTFontGetAscent(ctFont) + CTFontGetDescent(ctFont)
    }
}
