import UIKit

struct InlineBackground: Hashable {
    struct Border: Hashable {
        let color: UIColor
        let width: CGFloat
    }

    struct Style: Hashable {
        let fillColor: UIColor?
        let border: Border?
        let cornerRadius: CGFloat

        init?(_ style: ElementStyle) {
            let cornerRadius = max(0, style.cornerRadius ?? 0)
            var border: Border?
            if let color = style.borderColor, let width = style.borderWidth, width > 0 {
                border = Border(color: color, width: width)
            }
            guard border != nil || (cornerRadius > 0 && style.backgroundColor != nil) else { return nil }
            fillColor = style.backgroundColor
            self.border = border
            self.cornerRadius = cornerRadius
        }
    }

    let style: Style
    let linkStart: Int
    let underlay: UIColor?

    func beneath(highlight: UIColor) -> InlineBackground {
        guard style.fillColor == nil, underlay == nil else { return self }
        return InlineBackground(style: style, linkStart: linkStart, underlay: highlight)
    }

    static func reserveLineHeight(in output: NSMutableAttributedString) {
        guard isPresent(in: output) else { return }
        let string = output.mutableString
        var paragraphs: [NSRange] = []
        var widestBorder: CGFloat = 0
        let full = NSRange(location: 0, length: output.length)
        output.enumerateAttribute(MarkdownAttribute.inlineBackground, in: full, options: []) { value, range, _ in
            guard let border = (value as? InlineBackground)?.style.border else { return }
            widestBorder = max(widestBorder, border.width)
            if !(paragraphs.last.map { NSLocationInRange(range.location, $0) } ?? false) {
                paragraphs.append(string.paragraphRange(for: range))
            }
        }
        for paragraph in paragraphs {
            fitLines(of: paragraph, in: output)
        }
        if widestBorder > 0 {
            output.addAttribute(MarkdownAttribute.inlineBorderWidth, value: widestBorder, range: NSRange(location: 0, length: 1))
        }
    }

    static func borderRoom(in text: NSAttributedString) -> CGFloat {
        guard text.length > 0 else { return 0 }
        return CGFloat((text.attribute(MarkdownAttribute.inlineBorderWidth, at: 0, effectiveRange: nil) as? NSNumber)?.doubleValue ?? 0)
    }

    private static func fitLines(of paragraph: NSRange, in output: NSMutableAttributedString) {
        let style = output.attribute(.paragraphStyle, at: paragraph.location, effectiveRange: nil) as? NSParagraphStyle
        var natural: CGFloat = 0
        var needed: CGFloat = 0
        output.enumerateAttributes(in: paragraph, options: []) { attributes, _, _ in
            guard let font = attributes[.font] as? UIFont else { return }
            let height = ParagraphStyleHelpers.typographicLineHeight(for: font)
            natural = max(natural, height)
            if let border = (attributes[MarkdownAttribute.inlineBackground] as? InlineBackground)?.style.border {
                needed = max(needed, lineHeight(fitting: border.width, around: height))
            }
        }
        let fixed = max(style?.minimumLineHeight ?? 0, style?.maximumLineHeight ?? 0)
        let target = max(needed, ceil(natural))
        guard target > (fixed > 0 ? fixed : natural) else { return }
        output.removeAttribute(.baselineOffset, range: paragraph)
        ParagraphStyleHelpers.applyBlockLineHeight(to: output, range: paragraph, lineHeight: target)
    }

    private static func lineHeight(fitting border: CGFloat, around natural: CGFloat) -> CGFloat {
        var height = ceil(natural + 2 * border)
        while height - natural - ParagraphStyleHelpers.baselineRaise(lineHeight: height, naturalHeight: natural) < border {
            height += 1
        }
        return height
    }

    static func isPresent(in text: NSAttributedString) -> Bool {
        guard text.length > 0 else { return false }
        let full = NSRange(location: 0, length: text.length)
        var absentRun = NSRange()
        let first = text.attribute(MarkdownAttribute.inlineBackground, at: 0, longestEffectiveRange: &absentRun, in: full)
        return first != nil || absentRun != full
    }
}
