import UIKit

struct BlockDrawContext {
    let context: CGContext
    let textStorage: NSTextStorage
    let textLayoutManager: NSTextLayoutManager
    let contentManager: NSTextContentManager
    let containerWidth: CGFloat
    let origin: CGPoint
    let visibleCharacterRange: NSRange
    let decorationConfig: BlockDecorationConfig
}

/// Drawing context for chrome placed beside a paragraph's first line (list
/// markers, task checkboxes, admonition icons).
struct MarkerDrawContext {
    let context: CGContext
    let textStorage: NSTextStorage
    let textLayoutManager: NSTextLayoutManager
    let contentManager: NSTextContentManager
    let origin: CGPoint
    let visibleCharacterRange: NSRange
    let decorationConfig: BlockDecorationConfig
}

/// Where a paragraph's marker column ends (`markerX`, a gap before the text
/// in LTR or after it in RTL) and where its first line's visual baseline
/// sits, in decoration-view coordinates.
struct ParagraphMarkerLayout {
    let markerX: CGFloat
    let visualBaselineY: CGFloat

    init(
        paragraphRange: NSRange,
        attrs: [NSAttributedString.Key: Any],
        gap: CGFloat,
        isRTL: Bool,
        drawContext: MarkerDrawContext
    ) {
        let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle
        let textStartX = paragraphStyle?.headIndent ?? paragraphStyle?.firstLineHeadIndent ?? 0
        let font = (attrs[.font] as? UIFont) ?? UIFont.systemFont(ofSize: 16)
        var segmentFrame = CGRect(x: textStartX, y: 0, width: 0, height: 0)
        var baselineFromLineTop = font.ascender

        if let textRange = TextLayoutHelpers.textRange(paragraphRange, in: drawContext.contentManager) {
            drawContext.textLayoutManager.enumerateTextSegments(
                in: textRange,
                type: .standard,
                options: []
            ) { _, frame, baseline, _ in
                segmentFrame = frame
                baselineFromLineTop = baseline
                return false
            }
        }

        let layoutBaselineY = drawContext.origin.y + segmentFrame.minY + baselineFromLineTop
        let baselineOffset = CGFloat((attrs[.baselineOffset] as? NSNumber)?.doubleValue ?? 0)
        visualBaselineY = layoutBaselineY - baselineOffset

        if isRTL {
            let textEndX = max(segmentFrame.maxX, textStartX)
            markerX = drawContext.origin.x + textEndX + gap
        } else {
            let textOriginX = segmentFrame.width > 0 ? segmentFrame.minX : textStartX
            markerX = drawContext.origin.x + textOriginX - gap
        }
    }

    /// A `size` square whose trailing edge sits at the marker boundary,
    /// centered on the first line's cap height.
    func markerRect(size: CGFloat, font: UIFont, isRTL: Bool) -> CGRect {
        let originX = isRTL ? markerX : markerX - size
        let centerY = visualBaselineY - font.capHeight / 2
        return CGRect(x: originX, y: centerY - size / 2, width: size, height: size)
    }
}

enum TextLayoutHelpers {
    static func nsRange(_ textRange: NSTextRange, in contentManager: NSTextContentManager) -> NSRange? {
        let start = contentManager.offset(
            from: contentManager.documentRange.location,
            to: textRange.location
        )
        let end = contentManager.offset(
            from: contentManager.documentRange.location,
            to: textRange.endLocation
        )
        guard start != NSNotFound, end != NSNotFound, end >= start else { return nil }
        return NSRange(location: start, length: end - start)
    }

    static func textRange(_ range: NSRange, in contentManager: NSTextContentManager) -> NSTextRange? {
        guard let startLocation = contentManager.location(
            contentManager.documentRange.location,
            offsetBy: range.location
        ),
        let endLocation = contentManager.location(startLocation, offsetBy: range.length) else {
            return nil
        }
        return NSTextRange(location: startLocation, end: endLocation)
    }

    static func rangesIntersect(_ lhs: NSRange, _ rhs: NSRange) -> Bool {
        NSIntersectionRange(lhs, rhs).length > 0
    }

    static func paragraphIsRTL(_ style: NSParagraphStyle?) -> Bool {
        guard let style else {
            return UIView.userInterfaceLayoutDirection(
                for: UIView.appearance().semanticContentAttribute
            ) == .rightToLeft
        }
        if style.baseWritingDirection != .natural {
            return style.baseWritingDirection == .rightToLeft
        }
        return UIView.userInterfaceLayoutDirection(
            for: UIView.appearance().semanticContentAttribute
        ) == .rightToLeft
    }
}
