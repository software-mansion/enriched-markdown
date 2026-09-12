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

struct ListDrawContext {
    let context: CGContext
    let textStorage: NSTextStorage
    let textLayoutManager: NSTextLayoutManager
    let contentManager: NSTextContentManager
    let origin: CGPoint
    let visibleCharacterRange: NSRange
    let decorationConfig: BlockDecorationConfig
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

    /// Calls `body` with the view-space frame of each TextKit 2 segment of
    /// `range` (one per line piece), laying out on demand.
    static func enumerateSegmentFrames(of range: NSRange, in textView: UITextView, _ body: (CGRect) -> Void) {
        guard let textLayoutManager = textView.textLayoutManager,
              let contentManager = textLayoutManager.textContentManager,
              let textRange = textRange(range, in: contentManager)
        else { return }

        let inset = textView.textContainerInset
        textLayoutManager.ensureLayout(for: textRange)
        textLayoutManager.enumerateTextSegments(in: textRange, type: .standard, options: []) { _, frame, _, _ in
            body(frame.offsetBy(dx: inset.left, dy: inset.top))
            return true
        }
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
