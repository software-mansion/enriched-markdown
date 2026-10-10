import EnrichedMarkdown
import UIKit

extension SpoilerOverlayView {
    /// Delay before this segment's reveal so a spoiler that wraps reveals
    /// line by line, first to last, instead of every line at once.
    func revealDelay(stagger: TimeInterval) -> TimeInterval {
        Double(segmentIndex) * stagger
    }

    /// Crossfades the overlay into the text beneath it once the two match,
    /// so the opaque backdrop leaves smoothly instead of in one frame when
    /// the library removes the view.
    func fadeOut(completion: @escaping () -> Void) {
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState]
        ) {
            self.alpha = 0
        } completion: { _ in
            completion()
        }
    }
}

// MARK: - Scrambling

let cipherGlyphs = Array("ABCDEFGHJKLMNPQRSTUVWXYZ023456789#$%&*+=<>?")

extension SpoilerOverlayView {
    /// The composed character sequences of `concealedText`, the units that
    /// `scrambledConcealedText` swaps, so an emoji is replaced whole.
    func concealedClusters() -> [NSRange] {
        let source = concealedText.string as NSString
        var clusters: [NSRange] = []
        source.enumerateSubstrings(
            in: NSRange(location: 0, length: source.length),
            options: .byComposedCharacterSequences
        ) { _, range, _, _ in
            clusters.append(range)
        }
        return clusters
    }

    /// `concealedText` with the first `resolvedFraction` of `clusters` as
    /// written and the rest as random cipher glyphs in `glyphColor`,
    /// whitespace kept. Scrambling keeps the original attributes, so bold
    /// stays bold; replacing back to front keeps the earlier ranges valid.
    func scrambledConcealedText(
        clusters: [NSRange],
        resolvedFraction: Double,
        glyphColor: UIColor
    ) -> NSAttributedString {
        let resolvedCount = Int((Double(clusters.count) * resolvedFraction).rounded(.down))
        let text = NSMutableAttributedString(attributedString: concealedText)
        let source = concealedText.string as NSString
        for range in clusters.dropFirst(resolvedCount).reversed() {
            let original = source.substring(with: range)
            guard original.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { continue }
            let glyph = String(cipherGlyphs.randomElement() ?? "#")
            text.replaceCharacters(in: range, with: glyph)
            text.addAttribute(
                .foregroundColor,
                value: glyphColor,
                range: NSRange(location: range.location, length: (glyph as NSString).length)
            )
        }
        return text
    }
}
