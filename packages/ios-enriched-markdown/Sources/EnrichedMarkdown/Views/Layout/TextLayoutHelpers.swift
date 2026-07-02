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
}
