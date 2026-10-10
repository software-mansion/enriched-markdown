import EnrichedMarkdown
import UIKit

/// Owl post: feathers in the spoiler color drift down across the line,
/// swaying and slowly tumbling, and settle over the words. On reveal a gust
/// from the left whips them away, spinning, and the words are underneath.
final class FeathersOverlayView: FrameAnimatedOverlayView {
    /// Feather length in points, and one feather per this many square points.
    private static let length: CGFloat = 17
    private static let density: CGFloat = 1 / 55
    /// Fall and sway, in points per second and points.
    private static let fall: ClosedRange<CGFloat> = 5...11
    private static let sway: CGFloat = 4
    /// The gust: how long the front takes to cross, and how fast feathers fly.
    private static let gustUntil = 0.7
    private static let gustSpeed: CGFloat = 320
    private static let feather: CGFloat = 16

    private struct Feather {
        var position: CGPoint
        let fallSpeed: CGFloat
        let swayPhase: Double
        let swayRate: Double
        var angle: CGFloat
        let tumble: CGFloat
        let scale: CGFloat
        let flip: CGFloat
    }

    private var sharp: CGImage?
    private var feathers: [Feather] = []
    private let startTime = CACurrentMediaTime()
    private var lastTime = CACurrentMediaTime()
    private var tint: UIColor = .secondaryLabel

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        tint = style.color ?? .secondaryLabel
        idleFramesPerSecond = 24
        revealDuration = 1.1
        lineStagger = 0.4
    }

    override func prepare() {
        guard let sharp = concealedTextImage().cgImage else { return }
        self.sharp = sharp
        let width = CGFloat(sharp.width)
        let height = CGFloat(sharp.height)
        let count = max(6, Int(bounds.width * bounds.height * Self.density))
        feathers = (0..<count).map { _ in
            Feather(
                position: CGPoint(x: .random(in: 0...width), y: .random(in: 0...height)),
                fallSpeed: .random(in: Self.fall) * displayScale,
                swayPhase: .random(in: 0...(2 * .pi)),
                swayRate: .random(in: 0.8...1.6),
                angle: .random(in: -0.6...0.6),
                tumble: .random(in: -0.5...0.5),
                scale: .random(in: 0.8...1.15),
                flip: Bool.random() ? 1 : -1
            )
        }
    }

    override func draw(progress: Double?) {
        guard let sharp else { return }
        let now = CACurrentMediaTime()
        let elapsed = min(now - lastTime, 0.1)
        lastTime = now
        let time = now - startTime
        let width = CGFloat(sharp.width)
        let height = CGFloat(sharp.height)
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let feather = Self.feather * displayScale
        let front = progress.map { -feather + (width + 2 * feather) * easeInOut(min(1, $0 / Self.gustUntil)) } ?? -feather * 2
        advance(by: elapsed, time: time, width: width, height: height, front: front, gusting: progress != nil)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: height)
            cgContext.scaleBy(x: 1, y: -1)
            if progress != nil {
                cgContext.saveGState()
                if let mask = sweepMask(width: Int(width), head: front, feather: feather, keepsAhead: false) {
                    cgContext.clip(to: rect, mask: mask)
                }
                cgContext.draw(sharp, in: rect)
                cgContext.restoreGState()
            }
            for feather in feathers where feather.position.x < width + Self.length * 2 * displayScale {
                drawFeather(feather, in: cgContext, time: time)
            }
        }
        layer.contents = image.cgImage
    }

    /// Falling and swaying while idle; once the gust front passes a feather
    /// it flies off to the right, spinning, and never comes back.
    private func advance(by elapsed: CFTimeInterval, time: Double, width: CGFloat, height: CGFloat, front: CGFloat, gusting: Bool) {
        let sway = Self.sway * displayScale
        for index in feathers.indices {
            var feather = feathers[index]
            let caught = gusting && feather.position.x < front
            if caught {
                feather.position.x += Self.gustSpeed * displayScale * elapsed
                feather.position.y += Self.gustSpeed * 0.25 * displayScale * elapsed
                feather.angle += feather.tumble * 12 * elapsed
            } else {
                feather.position.y -= feather.fallSpeed * elapsed
                feather.position.x += sway * CGFloat(cos(time * feather.swayRate + feather.swayPhase)) * elapsed
                feather.angle = feather.tumble + 0.35 * CGFloat(sin(time * feather.swayRate + feather.swayPhase))
                // Off the bottom, back in at the top with little time unseen.
                let margin = Self.length * displayScale * 0.35
                if feather.position.y < -margin {
                    feather.position.y = height + margin
                    feather.position.x = .random(in: 0...width)
                }
            }
            feathers[index] = feather
        }
    }

    /// A quill with a long, slightly lopsided vane, fine light barbs angled
    /// toward the tip, and a bare stem at the base.
    private func drawFeather(_ feather: Feather, in cgContext: CGContext, time: Double) {
        let length = Self.length * displayScale * feather.scale
        let halfWidth = length * 0.15
        let base = -length / 2
        let tip = length / 2
        let vaneStart = base + length * 0.22
        cgContext.saveGState()
        cgContext.translateBy(x: feather.position.x, y: feather.position.y)
        cgContext.rotate(by: feather.angle + .pi / 2)
        cgContext.scaleBy(x: feather.flip, y: 1)

        let vane = CGMutablePath()
        vane.move(to: CGPoint(x: 0, y: vaneStart))
        vane.addQuadCurve(to: CGPoint(x: 0, y: tip), control: CGPoint(x: halfWidth * 2.4, y: base + length * 0.62))
        vane.addQuadCurve(to: CGPoint(x: 0, y: vaneStart), control: CGPoint(x: -halfWidth * 1.5, y: base + length * 0.5))
        cgContext.addPath(vane)
        cgContext.setFillColor(tint.withAlphaComponent(0.92).cgColor)
        cgContext.fillPath()
        cgContext.addPath(vane)
        cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
        cgContext.setLineWidth(displayScale * 0.5)
        cgContext.strokePath()

        // Barbs: fine light lines sweeping from the quill toward the tip.
        cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.4).cgColor)
        cgContext.setLineWidth(displayScale * 0.45)
        for step in 0..<9 {
            let along = vaneStart + (tip - vaneStart) * (0.08 + 0.82 * CGFloat(step) / 8)
            let reach = 1 - CGFloat(step) / 10
            cgContext.move(to: CGPoint(x: 0, y: along))
            cgContext.addLine(to: CGPoint(x: halfWidth * 1.7 * reach, y: along + length * 0.11))
            cgContext.move(to: CGPoint(x: 0, y: along))
            cgContext.addLine(to: CGPoint(x: -halfWidth * 1.1 * reach, y: along + length * 0.09))
        }
        cgContext.strokePath()

        // The quill: a light stem running the whole length.
        cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        cgContext.setLineWidth(displayScale * 0.8)
        cgContext.move(to: CGPoint(x: 0, y: base))
        cgContext.addQuadCurve(to: CGPoint(x: 0, y: tip), control: CGPoint(x: halfWidth * 0.3, y: 0))
        cgContext.strokePath()
        cgContext.restoreGState()
    }
}

struct FeathersOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        FeathersOverlayView(style: style, charRange: charRange)
    }
}
