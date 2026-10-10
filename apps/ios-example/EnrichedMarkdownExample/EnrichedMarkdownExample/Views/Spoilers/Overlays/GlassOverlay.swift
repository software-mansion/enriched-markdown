import CoreImage
import EnrichedMarkdown
import UIKit

/// A frosted pane: an opaque sheet carrying the text blurred into smudges
/// in the spoiler color under a faint white veil, with a slow sheen sliding
/// across the glass, drawn over the crisp text it hides. On reveal
/// a soft-edged wipe sweeps left to right, like a hand clearing
/// condensation, and the crisp text shows through behind it.
final class GlassOverlayView: FrameAnimatedOverlayView {
    /// Blur of the text under the frost, in points.
    private static let blurSigma: CGFloat = 6
    /// Soft edge of the wipe, in points.
    private static let feather: CGFloat = 18
    /// Width of the moving highlight, in points, and seconds per sweep.
    private static let sheenWidth: CGFloat = 40
    private static let sheenPeriod = 3.5
    private static let veilAlpha: CGFloat = 0.07

    private var sharp: CGImage?
    private var frost: CGImage?
    private var tint: UIColor = .secondaryLabel
    private let startTime = CACurrentMediaTime()

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        tint = style.color ?? .secondaryLabel
        idleFramesPerSecond = 20
        revealDuration = 0.9
        lineStagger = 0.45
    }

    override func prepare() {
        guard let sharp = concealedTextImage().cgImage else { return }
        self.sharp = sharp
        let size = CGSize(width: sharp.width, height: sharp.height)
        let rect = CGRect(origin: .zero, size: size)

        var blurred: CGImage?
        if let input = CIImage(image: UIImage(cgImage: sharp)) {
            let output = input
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: Self.blurSigma * displayScale])
                .cropped(to: input.extent)
            blurred = Self.imageContext.createCGImage(output, from: input.extent)
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        frost = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: size.height)
            cgContext.scaleBy(x: 1, y: -1)
            // Smudges take the spoiler color...
            if let blurred {
                cgContext.draw(blurred, in: rect)
            }
            cgContext.setBlendMode(.sourceAtop)
            cgContext.setFillColor(tint.withAlphaComponent(0.85).cgColor)
            cgContext.fill(rect)
            // ...on an opaque sheet that hides the sharp text drawn under it
            // until the wipe clears it, under a faint veil.
            cgContext.setBlendMode(.destinationOver)
            cgContext.setFillColor((backgroundColor ?? .systemBackground).cgColor)
            cgContext.fill(rect)
            cgContext.setBlendMode(.normal)
            cgContext.setFillColor(UIColor.white.withAlphaComponent(Self.veilAlpha).cgColor)
            cgContext.fill(rect)
        }.cgImage
    }

    override func draw(progress: Double?) {
        guard let sharp, let frost else { return }
        let width = CGFloat(sharp.width)
        let height = CGFloat(sharp.height)
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let feather = Self.feather * displayScale
        // The wipe front: parked off the left edge while idle, sweeping past
        // the right edge by the end of the reveal.
        let head = progress.map { -feather + (width + 2 * feather) * easeInOut($0) } ?? -feather
        let time = CACurrentMediaTime() - startTime

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: height)
            cgContext.scaleBy(x: 1, y: -1)
            cgContext.draw(sharp, in: rect)

            cgContext.saveGState()
            if let mask = sweepMask(width: Int(width), head: head, feather: feather, keepsAhead: true) {
                cgContext.clip(to: rect, mask: mask)
            }
            cgContext.draw(frost, in: rect)
            drawSheen(in: cgContext, width: width, height: height, time: time)
            cgContext.restoreGState()
        }
        layer.contents = image.cgImage
    }

    /// A soft highlight band gliding across the pane.
    private func drawSheen(in cgContext: CGContext, width: CGFloat, height: CGFloat, time: Double) {
        let band = Self.sheenWidth * displayScale
        let phase = CGFloat((time / Self.sheenPeriod).truncatingRemainder(dividingBy: 1))
        let center = -band + (width + 2 * band) * phase
        let colors = [
            UIColor.white.withAlphaComponent(0).cgColor,
            UIColor.white.withAlphaComponent(0.14).cgColor,
            UIColor.white.withAlphaComponent(0).cgColor
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1]) else { return }
        cgContext.drawLinearGradient(
            gradient,
            start: CGPoint(x: center - band, y: 0),
            end: CGPoint(x: center + band, y: height * 0.6),
            options: []
        )
    }
}

struct GlassOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        GlassOverlayView(style: style, charRange: charRange)
    }
}
