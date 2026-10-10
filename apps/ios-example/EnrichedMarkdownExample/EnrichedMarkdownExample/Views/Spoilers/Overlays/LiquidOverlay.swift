import EnrichedMarkdown
import UIKit

/// Molten letters: every pixel row of the text slides sideways on two
/// overlapping waves that keep rolling, and the whole thing takes the
/// spoiler color, so the words are unreadable while they ripple. On reveal
/// the waves flatten and the color cools into the text's own.
final class LiquidOverlayView: FrameAnimatedOverlayView {
    /// Sideways travel at full strength, in points.
    private static let amplitude: CGFloat = 9
    /// Wavelengths of the two waves, in points; short enough to shear glyphs.
    private static let wavelengths: (CGFloat, CGFloat) = (7, 13)
    /// Roll speeds of the two waves, in radians per second.
    private static let speeds: (Double, Double) = (4, -2.5)

    private var textImage: CGImage?
    private var rows: [CGImage] = []
    private var tint: UIColor = .secondaryLabel
    private let startTime = CACurrentMediaTime()
    private let phase = Double.random(in: 0...(2 * .pi))

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        tint = style.color ?? .secondaryLabel
        idleFramesPerSecond = 24
        revealDuration = 0.8
        lineStagger = 0.4
    }

    override func prepare() {
        guard let image = concealedTextImage().cgImage else { return }
        textImage = image
        rows = (0..<image.height).compactMap { row in
            image.cropping(to: CGRect(x: 0, y: row, width: image.width, height: 1))
        }
    }

    override func draw(progress: Double?) {
        guard let textImage else { return }
        // Full ripple while idle; on reveal it settles, fast at first.
        let strength = progress.map { pow(1 - $0, 2) } ?? 1
        let amplitude = Self.amplitude * displayScale * strength
        let time = CACurrentMediaTime() - startTime
        let width = CGFloat(textImage.width)
        let height = CGFloat(textImage.height)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: height)
            cgContext.scaleBy(x: 1, y: -1)
            for (index, row) in rows.enumerated() {
                let rowY = CGFloat(index)
                let offset = amplitude * wave(atRow: rowY, time: time)
                cgContext.draw(row, in: CGRect(x: offset, y: height - 1 - rowY, width: width, height: 1))
            }
            // Molten metal takes the spoiler color and cools to the text's own.
            cgContext.setBlendMode(.sourceAtop)
            cgContext.setFillColor(tint.withAlphaComponent(strength).cgColor)
            cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        layer.contents = image.cgImage
    }
}

extension LiquidOverlayView {
    /// Two rolling sine waves summed, in -1...1.
    private func wave(atRow rowY: CGFloat, time: Double) -> CGFloat {
        let first: Double = 2 * .pi * Double(rowY) / Double(Self.wavelengths.0 * displayScale)
        let second: Double = 2 * .pi * Double(rowY) / Double(Self.wavelengths.1 * displayScale)
        let sum: Double = 0.6 * sin(first + time * Self.speeds.0 + phase) + 0.4 * sin(second + time * Self.speeds.1 + phase)
        return CGFloat(sum)
    }
}

struct LiquidOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        LiquidOverlayView(style: style, charRange: charRange)
    }
}
