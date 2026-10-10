import CoreText
import EnrichedMarkdown
import UIKit

/// A split-flap board: every character is a reel spinning upward through
/// cipher glyphs in the spoiler color, each at its own pace. On reveal the
/// reels lock onto the real letters one by one, left to right.
///
/// Rendering is cheap: a handful of scrambled variants of the line are drawn
/// once, and a frame crops two of them per reel.
final class ReelsOverlayView: FrameAnimatedOverlayView {
    private static let variantCount = 10
    /// Glyphs per second while spinning.
    private static let speeds: ClosedRange<Double> = 3.5...6
    /// Share of the reveal before the first reel locks; the rest lock in
    /// turn over most of what remains.
    private static let firstLock = 0.15
    private static let lastLock = 0.9

    private struct Reel {
        /// Pixel column of this character, rows counted from the top.
        let cell: CGRect
        let isBlank: Bool
        var variant: Int
        /// How far the current glyph has scrolled up, in 0..<1.
        var phase: Double
        let speed: Double
        var isLocked = false
    }

    private var realImage: CGImage?
    private var variants: [CGImage] = []
    private var reels: [Reel] = []
    private var lastTime = CACurrentMediaTime()
    private var glyphColor: UIColor = .secondaryLabel

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        glyphColor = style.color ?? .secondaryLabel
        idleFramesPerSecond = 24
        revealDuration = 1
        lineStagger = 0.45
    }

    override func prepare() {
        guard let real = concealedTextImage().cgImage else { return }
        realImage = real
        let clusters = concealedClusters()
        variants = (0..<Self.variantCount).compactMap { _ in
            concealedTextImage(scrambledConcealedText(clusters: clusters, resolvedFraction: 0, glyphColor: glyphColor)).cgImage
        }

        // Character columns come from the same line layout the image used.
        let line = CTLineCreateWithAttributedString(fontAttributed(concealedText))
        let source = concealedText.string as NSString
        let height = CGFloat(real.height)
        reels = clusters.map { range in
            let start = CTLineGetOffsetForStringIndex(line, range.location, nil) * displayScale
            let end = CTLineGetOffsetForStringIndex(line, range.location + range.length, nil) * displayScale
            return Reel(
                cell: CGRect(x: floor(start), y: 0, width: ceil(end) - floor(start), height: height),
                isBlank: source.substring(with: range).rangeOfCharacter(from: .whitespacesAndNewlines) != nil,
                variant: Int.random(in: 0..<Self.variantCount),
                phase: .random(in: 0..<1),
                speed: .random(in: Self.speeds)
            )
        }
    }

    override func draw(progress: Double?) {
        guard let realImage, !variants.isEmpty else { return }
        let now = CACurrentMediaTime()
        let elapsed = min(now - lastTime, 0.1)
        lastTime = now
        advance(by: elapsed, progress: progress)

        let width = CGFloat(realImage.width)
        let height = CGFloat(realImage.height)
        let seam = CGRect(x: 0, y: (height - displayScale) / 2, width: width, height: displayScale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: height)
            cgContext.scaleBy(x: 1, y: -1)
            for (index, reel) in reels.enumerated() where !reel.isBlank {
                cgContext.saveGState()
                cgContext.clip(to: reel.cell)
                if reel.isLocked {
                    draw(realImage, cell: reel.cell, scrolledBy: 0, in: cgContext)
                } else {
                    let next = locks(index, at: progress) ? realImage : variants[(reel.variant + 1) % variants.count]
                    let scroll = CGFloat(reel.phase) * height
                    draw(variants[reel.variant], cell: reel.cell, scrolledBy: scroll, in: cgContext)
                    draw(next, cell: reel.cell, scrolledBy: scroll - height, in: cgContext)
                    if let seamColor = backgroundColor?.cgColor {
                        cgContext.setFillColor(seamColor)
                        cgContext.fill(seam)
                    }
                }
                cgContext.restoreGState()
            }
        }
        layer.contents = image.cgImage
    }

    /// Spins every running reel; one that has passed its lock point stops
    /// as its next glyph, the real one, scrolls into place.
    private func advance(by elapsed: CFTimeInterval, progress: Double?) {
        for index in reels.indices where !reels[index].isBlank && !reels[index].isLocked {
            if let progress, progress >= 1 {
                reels[index].isLocked = true
                continue
            }
            reels[index].phase += elapsed * reels[index].speed
            guard reels[index].phase >= 1 else { continue }
            reels[index].phase -= 1
            if locks(index, at: progress) {
                reels[index].isLocked = true
            } else {
                reels[index].variant = (reels[index].variant + 1) % variants.count
            }
        }
    }

    private func locks(_ index: Int, at progress: Double?) -> Bool {
        guard let progress else { return false }
        let share = Double(index) / Double(max(reels.count - 1, 1))
        return progress >= Self.firstLock + (Self.lastLock - Self.firstLock) * share
    }

    /// Draws this reel's column of `image`, shifted up by `scroll` pixels
    /// in the flipped context.
    private func draw(_ image: CGImage, cell: CGRect, scrolledBy scroll: CGFloat, in cgContext: CGContext) {
        guard let piece = image.cropping(to: cell) else { return }
        cgContext.draw(piece, in: cell.offsetBy(dx: 0, dy: scroll))
    }

    /// CoreText lays out with its own font key; UIKit's is not guaranteed.
    private func fontAttributed(_ text: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: text)
        result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let font = value as? UIFont else { return }
            result.addAttribute(NSAttributedString.Key(kCTFontAttributeName as String), value: font, range: range)
        }
        return result
    }
}

struct ReelsOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        ReelsOverlayView(style: style, charRange: charRange)
    }
}
