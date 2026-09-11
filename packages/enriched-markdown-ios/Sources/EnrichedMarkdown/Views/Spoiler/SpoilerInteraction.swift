import UIKit

/// Spoiler lookups shared by the text view (overlay placement, tap
/// hit-testing) and the render store (reveal).
enum SpoilerInteraction {
    /// Runs still concealed, in document order.
    static func concealedRanges(in attributedText: NSAttributedString) -> [NSRange] {
        spoilerRanges(in: attributedText, concealedOnly: true)
    }

    /// Every spoiler run, concealed or revealed, in document order. A run's
    /// index here is stable across re-renders of the same source, unlike its
    /// character range, which moves with theme-dependent spacing.
    static func spoilerRanges(in attributedText: NSAttributedString) -> [NSRange] {
        spoilerRanges(in: attributedText, concealedOnly: false)
    }

    /// A copy of `attributedText` with the spoilers at `ordinals` revealed, or
    /// nil when none of them was concealed.
    static func revealing(in attributedText: NSAttributedString, ordinals: Set<Int>) -> NSAttributedString? {
        let ranges = spoilerRanges(in: attributedText)
        let targets = ordinals.filter { $0 < ranges.count }.map { ranges[$0] }
            .filter { isConcealed($0, in: attributedText) }
        guard !targets.isEmpty else { return nil }

        let result = NSMutableAttributedString(attributedString: attributedText)
        for range in targets {
            SpoilerConcealment.reveal(result, in: range)
        }
        return result
    }

    /// Whether any character of `range` is still concealed.
    static func isConcealed(_ range: NSRange, in attributedText: NSAttributedString) -> Bool {
        let clamped = NSIntersectionRange(range, NSRange(location: 0, length: attributedText.length))
        guard clamped.length > 0 else { return false }
        var concealed = false
        attributedText.enumerateAttribute(MarkdownAttribute.spoiler, in: clamped) { value, _, stop in
            if MarkdownAttributeValue.boolValue(from: value) {
                concealed = true
                stop.pointee = true
            }
        }
        return concealed
    }

    private static func spoilerRanges(in attributedText: NSAttributedString, concealedOnly: Bool) -> [NSRange] {
        var ranges: [NSRange] = []
        attributedText.enumerateAttribute(
            MarkdownAttribute.spoiler,
            in: NSRange(location: 0, length: attributedText.length)
        ) { value, range, _ in
            guard value != nil, !concealedOnly || MarkdownAttributeValue.boolValue(from: value) else { return }
            ranges.append(range)
        }
        return ranges
    }
}
