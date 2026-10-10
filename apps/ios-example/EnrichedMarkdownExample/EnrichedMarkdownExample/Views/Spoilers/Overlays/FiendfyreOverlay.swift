import EnrichedMarkdown
import UIKit

/// Fiendfyre: flames licking up along the line under drifting dark smoke,
/// embers rising off them. On reveal a burn front sweeps left to right,
/// snuffing the flames and leaving the words glowing ember-orange behind it
/// before they cool to plain text.
final class FiendfyreOverlayView: FrameAnimatedOverlayView {
    private static let flame = UIColor(red: 1, green: 0.45, blue: 0.1, alpha: 1)
    private static let core = UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
    private static let smoke = UIColor(red: 0.12, green: 0.06, blue: 0.05, alpha: 1)
    /// One flame tongue per this many points.
    private static let tongueSpacing: CGFloat = 7
    private static let emberCount = 20
    private static let feather: CGFloat = 12
    private static let glowTrail: CGFloat = 70
    private static let sparkLife = 0.5

    private struct Ember {
        var position: CGPoint
        let speed: CGFloat
        let phase: Double
    }

    private struct Spark {
        var position: CGPoint
        let velocity: CGVector
        let born: Double
    }

    private var sharp: CGImage?
    private var tongues: [FlameTongue] = []
    private var embers: [Ember] = []
    private var sparks: [Spark] = []
    private let startTime = CACurrentMediaTime()
    private var lastTime = CACurrentMediaTime()

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        idleFramesPerSecond = 24
        revealDuration = 1.1
        lineStagger = 0.45
    }

    override func prepare() {
        guard let sharp = concealedTextImage().cgImage else { return }
        self.sharp = sharp
        let width = CGFloat(sharp.width)
        let height = CGFloat(sharp.height)
        tongues = FlameTongue.row(width: width, height: height, spacing: Self.tongueSpacing * displayScale)
        embers = (0..<Self.emberCount).map { _ in
            Ember(
                position: CGPoint(x: .random(in: 0...width), y: .random(in: 0...height)),
                speed: .random(in: 12...30) * displayScale,
                phase: .random(in: 0...(2 * .pi))
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
        let head = progress.map { -feather + (width + trail + 2 * feather) * easeInOut($0) } ?? -feather * 2
        if progress != nil, head < width + feather {
            for _ in 0..<3 {
                sparks.append(Spark(
                    position: CGPoint(x: head, y: .random(in: 0...height)),
                    velocity: CGVector(dx: .random(in: -30...50) * displayScale, dy: .random(in: 20...70) * displayScale),
                    born: time
                ))
            }
        }
        for index in sparks.indices {
            sparks[index].position.x += sparks[index].velocity.dx * elapsed
            sparks[index].position.y += sparks[index].velocity.dy * elapsed
        }
        sparks.removeAll { time - $0.born > Self.sparkLife }
        for index in embers.indices {
            embers[index].position.y += embers[index].speed * elapsed
            embers[index].position.x += CGFloat(sin(time * 3 + embers[index].phase)) * 0.5 * displayScale
            if embers[index].position.y > height + 4 * displayScale {
                embers[index].position = CGPoint(x: .random(in: 0...width), y: -2 * displayScale)
            }
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: height)
            cgContext.scaleBy(x: 1, y: -1)
            if progress != nil {
                drawBurntText(sharp, in: cgContext, rect: rect, head: head, feather: feather, trail: trail)
            }
            drawUnderglow(in: cgContext, width: width, height: height, time: time, head: head)
            drawSmoke(in: cgContext, width: width, height: height, time: time, head: head)
            drawFlames(in: cgContext, time: time, head: head, feather: feather)
            drawEmbers(in: cgContext, time: time, head: head)
            if progress != nil, head < width + feather {
                drawFront(in: cgContext, head: head, height: height, feather: feather)
                drawSparks(in: cgContext, time: time)
            }
        }
        layer.contents = image.cgImage
    }

    /// The fire's light on the ground, flickering along the baseline.
    private func drawUnderglow(in cgContext: CGContext, width: CGFloat, height: CGFloat, time: Double, head: CGFloat) {
        cgContext.setBlendMode(glowBlend)
        for index in 0..<4 {
            let offset = Double(index) * 1.3
            let center = CGPoint(x: width * (0.12 + 0.25 * CGFloat(index)), y: height * 0.1)
            guard center.x > head - width * 0.1 else { continue }
            let flicker = CGFloat(0.7 + 0.3 * sin(time * 7 + offset))
            let glow = (isOnLightBackdrop ? 0.14 : 0.3) * flicker
            let colors = [Self.flame.withAlphaComponent(glow).cgColor, Self.flame.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { continue }
            cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: width * 0.18, options: [])
        }
        cgContext.setBlendMode(.normal)
    }

    /// The burning edge: a white-hot band at the front.
    private func drawFront(in cgContext: CGContext, head: CGFloat, height: CGFloat, feather: CGFloat) {
        let colors = [
            Self.flame.withAlphaComponent(0).cgColor,
            UIColor.white.withAlphaComponent(0.9).cgColor,
            Self.core.withAlphaComponent(0.8).cgColor,
            Self.flame.withAlphaComponent(0).cgColor
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.45, 0.6, 1]) else { return }
        cgContext.setBlendMode(glowBlend)
        cgContext.drawLinearGradient(gradient, start: CGPoint(x: head - feather, y: 0), end: CGPoint(x: head + feather, y: 0), options: [])
        cgContext.setBlendMode(.normal)
    }

    private func drawSparks(in cgContext: CGContext, time: Double) {
        for spark in sparks {
            let alpha = CGFloat(1 - (time - spark.born) / Self.sparkLife)
            cgContext.setFillColor(Self.core.withAlphaComponent(alpha).cgColor)
            let size = 1.3 * displayScale
            cgContext.fillEllipse(in: CGRect(x: spark.position.x - size, y: spark.position.y - size, width: size * 2, height: size * 2))
        }
    }

    /// Dark clouds along the top, gone where the fire has been.
    private func drawSmoke(in cgContext: CGContext, width: CGFloat, height: CGFloat, time: Double, head: CGFloat) {
        for index in 0..<4 {
            let offset = Double(index) * 1.9
            let center = CGPoint(
                x: width * (0.12 + 0.25 * CGFloat(index)) + width * 0.05 * CGFloat(sin(time * 0.7 + offset)),
                y: height * 0.75 + height * 0.1 * CGFloat(sin(time * 1.1 + offset))
            )
            // Smoke reads as grime on a light page, so there the flames carry it alone.
            let alpha: CGFloat = center.x < head || isOnLightBackdrop ? 0 : 0.55
            guard alpha > 0 else { continue }
            let colors = [Self.smoke.withAlphaComponent(alpha).cgColor, Self.smoke.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { continue }
            cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: width * 0.15, options: [])
        }
    }

    /// Tongues of flame flickering up from the baseline; those the front has
    /// passed shrink away.
    private func drawFlames(in cgContext: CGContext, time: Double, head: CGFloat, feather: CGFloat) {
        FlameTongue.draw(
            tongues, in: cgContext, time: time, base: Self.tongueSpacing * displayScale * 0.9,
            palette: FlamePalette(outer: Self.flame, core: Self.core, blend: glowBlend)
        ) { position in
            1 - min(1, max(0, (head - position + feather) / (2 * feather)))
        }
    }

    private func drawEmbers(in cgContext: CGContext, time: Double, head: CGFloat) {
        for ember in embers {
            let glow = CGFloat(0.5 + 0.5 * abs(sin(time * 6 + ember.phase)))
            let alpha = ember.position.x < head ? glow * 0.3 : glow
            cgContext.setFillColor(Self.core.withAlphaComponent(alpha).cgColor)
            let size = 1.2 * displayScale
            cgContext.fillEllipse(in: CGRect(x: ember.position.x - size, y: ember.position.y - size, width: size * 2, height: size * 2))
        }
    }

    /// The words behind the front, glowing ember-orange and cooling with distance.
    private func drawBurntText(_ sharp: CGImage, in cgContext: CGContext, rect: CGRect, head: CGFloat, feather: CGFloat, trail: CGFloat) {
        cgContext.saveGState()
        if let mask = sweepMask(width: Int(rect.width), head: head, feather: feather, keepsAhead: false) {
            cgContext.clip(to: rect, mask: mask)
        }
        cgContext.draw(sharp, in: rect)
        if let glowMask = sweepMask(width: Int(rect.width), head: head - trail, feather: trail, keepsAhead: true) {
            cgContext.clip(to: rect, mask: glowMask)
        }
        cgContext.setBlendMode(glowBlend)
        cgContext.setShadow(offset: .zero, blur: 6 * displayScale, color: Self.flame.cgColor)
        cgContext.draw(sharp, in: rect)
        cgContext.setBlendMode(.sourceAtop)
        cgContext.setFillColor(Self.flame.withAlphaComponent(0.6).cgColor)
        cgContext.fill(rect)
        cgContext.restoreGState()
    }
}

struct FiendfyreOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        FiendfyreOverlayView(style: style, charRange: charRange)
    }
}
