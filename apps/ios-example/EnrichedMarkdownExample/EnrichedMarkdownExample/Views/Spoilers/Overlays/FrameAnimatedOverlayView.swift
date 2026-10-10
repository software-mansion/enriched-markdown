import CoreImage
import EnrichedMarkdown
import UIKit

/// An overlay driven frame by frame with a display link: while idle if
/// `idleFramesPerSecond` is above zero, and through a timed reveal that a
/// wrapped spoiler runs line by line. Subclasses cache what they need in
/// `prepare()` and render in `draw(progress:)`, where nil means idle.
class FrameAnimatedOverlayView: SpoilerOverlayView {
    /// Shared by the Core Image based effects; contexts are costly to make.
    static let imageContext = CIContext()

    var idleFramesPerSecond = 0
    var revealDuration: CFTimeInterval = 0.6
    /// Gap between the starts of consecutive lines of one spoiler.
    var lineStagger: CFTimeInterval = 0.35

    private var displayLink: CADisplayLink?
    private var revealStart: CFTimeInterval?
    private var onRevealed: (() -> Void)?
    private var isPrepared = false

    var displayScale: CGFloat { traitCollection.displayScale }

    /// True on a light page, where additive glows wash out and white
    /// highlights vanish; effects pick blend modes and colors by it.
    var isOnLightBackdrop: Bool {
        var white: CGFloat = 0, alpha: CGFloat = 0
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        let color = (backgroundColor ?? .systemBackground).resolvedColor(with: traitCollection)
        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return 0.299 * red + 0.587 * green + 0.114 * blue > 0.5
        }
        return color.getWhite(&white, alpha: &alpha) && white > 0.5
    }

    /// Additive on a dark backdrop, plain on a light one.
    var glowBlend: CGBlendMode { isOnLightBackdrop ? .normal : .plusLighter }

    /// `dark` on a dark backdrop, `light` on a light one.
    func highlight(_ dark: UIColor, onLight light: UIColor) -> UIColor {
        isOnLightBackdrop ? light : dark
    }

    /// A burst of light over the whole view, additive. On a page it is
    /// skipped altogether: any wash across a one-line view shows the view's
    /// top and bottom edges, so it reads as a colored box no matter how soft.
    func drawFlash(in cgContext: CGContext, rect: CGRect, color: UIColor, alpha: CGFloat) {
        guard alpha > 0.01, !isOnLightBackdrop else { return }
        cgContext.setBlendMode(.plusLighter)
        cgContext.setFillColor(color.withAlphaComponent(alpha).cgColor)
        cgContext.fill(rect)
        cgContext.setBlendMode(.normal)
    }

    /// Called once the view has its size, before the first draw.
    func prepare() {}

    /// Renders one frame; `progress` runs 0...1 through the reveal.
    func draw(progress: Double?) {}

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !isPrepared, !bounds.isEmpty else { return }
        isPrepared = true
        prepare()
        draw(progress: nil)
        if idleFramesPerSecond > 0 {
            startDisplayLink(framesPerSecond: idleFramesPerSecond)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window == nil else { return }
        stopDisplayLink()
    }

    override func animateReveal(completion: @escaping () -> Void) {
        onRevealed = completion
        revealStart = CACurrentMediaTime() + revealDelay(stagger: lineStagger)
        startDisplayLink(framesPerSecond: 60)
    }

    private func startDisplayLink(framesPerSecond: Int) {
        if displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(step))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
        displayLink?.preferredFramesPerSecond = framesPerSecond
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func step() {
        guard let revealStart else {
            draw(progress: nil)
            return
        }
        let progress = (CACurrentMediaTime() - revealStart) / revealDuration
        guard progress >= 0 else {
            // Waiting for the line above to finish: keep the idle look.
            draw(progress: nil)
            return
        }
        draw(progress: min(1, progress))
        guard progress >= 1 else { return }
        stopDisplayLink()
        let onRevealed = onRevealed
        self.onRevealed = nil
        fadeOut { onRevealed?() }
    }
}

extension FrameAnimatedOverlayView {
    /// A one-pixel-tall gray mask for `CGContext.clip(to:mask:)`, stretched
    /// across a line: white (kept) on one side of `head`, black on the
    /// other, feathered over `feather` pixels either side of it.
    func sweepMask(width: Int, head: CGFloat, feather: CGFloat, keepsAhead: Bool) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: width, height: 1, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ), let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        for column in 0..<width {
            let edge = (CGFloat(column) - (head - feather)) / (2 * feather)
            let clamped = max(0, min(1, edge))
            let smooth = clamped * clamped * (3 - 2 * clamped)
            pixels[column] = UInt8((keepsAhead ? smooth : 1 - smooth) * 255)
        }
        return context.makeImage()
    }

    /// A gray mask, white inside a circle around `center` and feathered at
    /// its rim, for a reveal that blooms outward from a point.
    func radialMask(size: CGSize, center: CGPoint, radius: CGFloat, feather: CGFloat) -> CGImage? {
        radialMask(size: size, centers: [center], radii: [radius], feather: feather)
    }

    /// The union of feathered circles, one per center with its own radius.
    func radialMask(size: CGSize, centers: [CGPoint], radii: [CGFloat], feather: CGFloat) -> CGImage? {
        let width = Int(size.width), height = Int(size.height)
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(origin: .zero, size: size))
        let colors = [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 1), CGColor(gray: 0, alpha: 1)] as CFArray
        context.setBlendMode(.lighten)
        for (center, radius) in zip(centers, radii) where radius > 0 {
            let inner = max(0, (radius - feather) / radius)
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(), colors: colors, locations: [0, inner, 1]) else { continue }
            context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        }
        return context.makeImage()
    }

    /// Ease-out with a small overshoot past 1 before settling.
    func easeOutBack(_ progress: Double) -> Double {
        let overshoot = 1.70158
        let shifted = progress - 1
        return 1 + (overshoot + 1) * shifted * shifted * shifted + overshoot * shifted * shifted
    }

    func easeInOut(_ progress: Double) -> CGFloat {
        let eased = progress < 0.5 ? 2 * progress * progress : 1 - pow(-2 * progress + 2, 2) / 2
        return CGFloat(eased)
    }
}
