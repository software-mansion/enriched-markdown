import CoreImage.CIFilterBuiltins
import EnrichedMarkdown
import UIKit

/// The text as a coarse mosaic that sharpens into the real glyphs on reveal.
final class PixelateOverlayView: FrameAnimatedOverlayView {
    private static let blockSize: CGFloat = 5

    private var textImage: CIImage?
    private var idleContents: CGImage?

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        revealDuration = 0.6
        lineStagger = 0.35
    }

    /// `CIPixellate` works in pixels; the block size is in points.
    private var concealedScale: CGFloat { Self.blockSize * displayScale }

    override func prepare() {
        textImage = CIImage(image: concealedTextImage())
    }

    override func draw(progress: Double?) {
        guard let progress else {
            if idleContents == nil {
                idleContents = mosaic(scale: concealedScale)
            }
            layer.contents = idleContents
            return
        }
        let eased = 1 - pow(1 - progress, 3)
        layer.contents = mosaic(scale: max(1, concealedScale * (1 - eased)))
    }

    private func mosaic(scale: CGFloat) -> CGImage? {
        guard let textImage else { return nil }
        let filter = CIFilter.pixellate()
        filter.inputImage = textImage
        filter.scale = Float(scale)
        filter.center = CGPoint(x: textImage.extent.midX, y: textImage.extent.midY)
        guard let output = filter.outputImage else { return nil }
        return Self.imageContext.createCGImage(output, from: textImage.extent)
    }
}

struct PixelateOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        PixelateOverlayView(style: style, charRange: charRange)
    }
}
