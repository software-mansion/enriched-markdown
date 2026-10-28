import UIKit

struct InlineBackground: Hashable {
    struct Border: Hashable {
        let color: UIColor
        let width: CGFloat
    }

    let fillColor: UIColor?
    let border: Border?
    let cornerRadius: CGFloat

    init?(style: ElementStyle) {
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

    static func isPresent(in text: NSAttributedString) -> Bool {
        guard text.length > 0 else { return false }
        let full = NSRange(location: 0, length: text.length)
        var absentRun = NSRange()
        let first = text.attribute(MarkdownAttribute.inlineBackground, at: 0, longestEffectiveRange: &absentRun, in: full)
        return first != nil || absentRun != full
    }
}
