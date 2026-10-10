import EnrichedMarkdown
import UIKit

/// A spell: the words hide in a drifting cloud of twinkling sparks and faint
/// mist in the spoiler color. On reveal a wand tip sweeps along the line;
/// sparks flare as it passes and are spent behind it, while the letters are
/// conjured in its wake with a glow that cools into plain text.
final class RevelioOverlayView: FrameAnimatedOverlayView {
    /// Sparks per square point of the line.
    private static let sparkDensity: CGFloat = 1 / 70
    private static let sparkSizes: ClosedRange<CGFloat> = 1.2...3.2
    /// Idle drift, in points per second.
    private static let drift: CGFloat = 4
    /// Soft edge of the conjuring front, in points.
    private static let feather = CGFloat(12)
    /// How far behind the front the glow lingers, and the flare zone
    /// around it, in points.
    private static let glowTrail: CGFloat = 70
    private static let flareZone: CGFloat = 16
    private static let wandRadius: CGFloat = 14

    private struct Spark {
        var position: CGPoint
        let size: CGFloat
        let phase: Double
        let rate: Double
        let velocity: CGVector
    }

    private var sharp: CGImage?
    private var sparks: [Spark] = []
    private var tint: UIColor = .secondaryLabel
    private let startTime = CACurrentMediaTime()
    private var lastTime = CACurrentMediaTime()

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        tint = style.color ?? .secondaryLabel
        idleFramesPerSecond = 24
        revealDuration = 1.1
        lineStagger = 0.5
    }

    override func prepare() {
        guard let sharp = concealedTextImage().cgImage else { return }
        self.sharp = sharp
        let width = CGFloat(sharp.width)
        let height = CGFloat(sharp.height)
        let count = max(10, Int(bounds.width * bounds.height * Self.sparkDensity))
        sparks = (0..<count).map { _ in
            Spark(
                position: CGPoint(x: .random(in: 0...width), y: .random(in: 0...height)),
                size: .random(in: Self.sparkSizes) * displayScale,
                phase: .random(in: 0...(2 * .pi)),
                rate: .random(in: 2...5),
                velocity: CGVector(
                    dx: .random(in: -Self.drift...Self.drift) * displayScale,
                    dy: .random(in: -Self.drift...Self.drift) * displayScale
                )
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
        let trail = Self.glowTrail * displayScale
        // The wand tip: parked off the left edge while idle, past the right
        // edge with its trail spent by the end of the reveal.
        let head = progress.map { -feather + (width + trail + 2 * feather) * easeInOut($0) } ?? -feather * 2
        drift(by: elapsed, width: width, height: height)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: height)
            cgContext.scaleBy(x: 1, y: -1)

            drawMist(in: cgContext, width: width, height: height, time: time, spent: head)
            if progress != nil {
                drawConjuredText(sharp, in: cgContext, rect: rect, head: head, feather: feather, trail: trail)
            }
            drawSparks(in: cgContext, time: time, head: head)
            if progress != nil, head < width + feather {
                drawWandTip(in: cgContext, head: head, height: height, time: time)
            }
        }
        layer.contents = image.cgImage
    }

    private func drift(by elapsed: CFTimeInterval, width: CGFloat, height: CGFloat) {
        for index in sparks.indices {
            var position = sparks[index].position
            position.x += sparks[index].velocity.dx * elapsed
            position.y += sparks[index].velocity.dy * elapsed
            position.x = (position.x + width).truncatingRemainder(dividingBy: width)
            position.y = (position.y + height).truncatingRemainder(dividingBy: height)
            sparks[index].position = position
        }
    }

    /// Three soft clouds that breathe and drift, gone where the wand has been.
    private func drawMist(in cgContext: CGContext, width: CGFloat, height: CGFloat, time: Double, spent: CGFloat) {
        for index in 0..<3 {
            let offset = Double(index) * 2.1
            let center = CGPoint(
                x: width * (0.2 + 0.3 * CGFloat(index)) + width * 0.08 * CGFloat(sin(time * 0.5 + offset)),
                y: height / 2 + height * 0.2 * CGFloat(cos(time * 0.7 + offset))
            )
            guard center.x > spent - width * 0.15 else { continue }
            let radius = width * 0.18 * (1 + 0.15 * CGFloat(sin(time * 0.9 + offset)))
            let colors = [tint.withAlphaComponent(0.16).cgColor, tint.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { continue }
            cgContext.drawRadialGradient(
                gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius,
                options: []
            )
        }
    }

    /// The text behind the front, plus a glow that fades with distance from it.
    private func drawConjuredText(
        _ sharp: CGImage, in cgContext: CGContext, rect: CGRect, head: CGFloat, feather: CGFloat, trail: CGFloat
    ) {
        cgContext.saveGState()
        if let mask = sweepMask(width: Int(rect.width), head: head, feather: feather, keepsAhead: false) {
            cgContext.clip(to: rect, mask: mask)
        }
        cgContext.draw(sharp, in: rect)
        // Glow: the text itself as a blurred, tinted shadow, strongest at
        // the front and gone `trail` behind it.
        if let glowMask = sweepMask(width: Int(rect.width), head: head - trail, feather: trail, keepsAhead: true) {
            cgContext.clip(to: rect, mask: glowMask)
        }
        cgContext.setBlendMode(glowBlend)
        cgContext.setShadow(offset: .zero, blur: 6 * displayScale, color: tint.withAlphaComponent(0.9).cgColor)
        cgContext.draw(sharp, in: rect)
        cgContext.restoreGState()
    }

    /// Four-point stars twinkling; the ones near the front flare, the ones
    /// behind it are spent.
    private func drawSparks(in cgContext: CGContext, time: Double, head: CGFloat) {
        let flareZone = Self.flareZone * displayScale
        for spark in sparks {
            let twinkle = 0.35 + 0.65 * abs(sin(time * spark.rate + spark.phase))
            let distanceBehind = head - spark.position.x
            var alpha = CGFloat(twinkle)
            var size = spark.size
            if abs(distanceBehind) < flareZone {
                let flare = 1 - abs(distanceBehind) / flareZone
                alpha = 1
                size *= 1 + 1.5 * flare
            } else if distanceBehind > 0 {
                alpha *= max(0, 1 - (distanceBehind - flareZone) / (flareZone * 3))
            }
            guard alpha > 0.01 else { continue }
            cgContext.setFillColor(tint.withAlphaComponent(alpha).cgColor)
            cgContext.addPath(starPath(at: spark.position, size: size))
            cgContext.fillPath()
            cgContext.setFillColor(highlight(.white, onLight: tint).withAlphaComponent(alpha * 0.9).cgColor)
            let core = size * 0.18
            cgContext.fillEllipse(in: CGRect(x: spark.position.x - core, y: spark.position.y - core, width: core * 2, height: core * 2))
        }
    }

    private func drawWandTip(in cgContext: CGContext, head: CGFloat, height: CGFloat, time: Double) {
        let center = CGPoint(x: head, y: height / 2 + height * 0.25 * CGFloat(sin(time * 7)))
        let radius = Self.wandRadius * displayScale
        let colors = [
            highlight(.white, onLight: tint).cgColor,
            tint.withAlphaComponent(0.8).cgColor,
            tint.withAlphaComponent(0).cgColor
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.25, 1]) else { return }
        cgContext.setBlendMode(glowBlend)
        cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        cgContext.setBlendMode(.normal)
    }

    private func starPath(at center: CGPoint, size: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let waist = size * 0.2
        path.move(to: CGPoint(x: center.x, y: center.y - size))
        path.addLine(to: CGPoint(x: center.x + waist, y: center.y - waist))
        path.addLine(to: CGPoint(x: center.x + size, y: center.y))
        path.addLine(to: CGPoint(x: center.x + waist, y: center.y + waist))
        path.addLine(to: CGPoint(x: center.x, y: center.y + size))
        path.addLine(to: CGPoint(x: center.x - waist, y: center.y + waist))
        path.addLine(to: CGPoint(x: center.x - size, y: center.y))
        path.addLine(to: CGPoint(x: center.x - waist, y: center.y - waist))
        path.closeSubpath()
        return path
    }
}

struct RevelioOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        RevelioOverlayView(style: style, charRange: charRange)
    }
}
