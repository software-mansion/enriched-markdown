import EnrichedMarkdown
import UIKit

/// Cipher glyphs churn in place of the words, then resolve left to right on
/// reveal.
final class DecodeOverlayView: FrameAnimatedOverlayView {
    private var clusters: [NSRange] = []
    private var glyphColor: UIColor = .systemGreen

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        glyphColor = style.color ?? .systemGreen
        idleFramesPerSecond = 14
        revealDuration = 0.8
        lineStagger = 0.45
    }

    override func prepare() {
        clusters = concealedClusters()
    }

    override func draw(progress: Double?) {
        let resolvedFraction = progress.map { 1 - pow(1 - $0, 2) } ?? 0
        let text = scrambledConcealedText(clusters: clusters, resolvedFraction: resolvedFraction, glyphColor: glyphColor)
        layer.contents = concealedTextImage(text).cgImage
    }
}

struct DecodeOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        DecodeOverlayView(style: style, charRange: charRange)
    }
}
