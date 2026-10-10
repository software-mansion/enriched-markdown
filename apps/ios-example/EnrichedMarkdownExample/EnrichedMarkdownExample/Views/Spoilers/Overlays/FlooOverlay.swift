import EnrichedMarkdown
import UIKit

/// Floo powder: emerald flames burning low along the baseline with green
/// sparks rising. On reveal they whoosh up in a green flash and the words
/// tumble out of the fire, spun and a little small, settling as the flames
/// die down.
final class FlooOverlayView: FrameAnimatedOverlayView {
    private static let green = UIColor(red: 0.1, green: 0.85, blue: 0.45, alpha: 1)
    private static let pale = UIColor(red: 0.75, green: 1, blue: 0.82, alpha: 1)
    private static let deepGreen = UIColor(red: 0.05, green: 0.5, blue: 0.28, alpha: 1)

    /// Emerald over a dark card; a deeper green on a light page.
    private var palette: FlamePalette {
        FlamePalette(outer: highlight(Self.green, onLight: Self.deepGreen), core: highlight(Self.pale, onLight: Self.green), blend: glowBlend)
    }
    private static let tongueSpacing: CGFloat = 7
    private static let sparkCount = 18
    private static let whooshUntil = 0.3

    private struct Spark {
        var position: CGPoint
        let speed: CGFloat
        let phase: Double
    }

    private var sharp: CGImage?
    private var tongues: [FlameTongue] = []
    private var sparks: [Spark] = []
    private let startTime = CACurrentMediaTime()
    private var lastTime = CACurrentMediaTime()

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        idleFramesPerSecond = 24
        revealDuration = 1.35
        lineStagger = 0.45
    }

    override func prepare() {
        guard let sharp = concealedTextImage().cgImage else { return }
        self.sharp = sharp
        let width = CGFloat(sharp.width)
        let height = CGFloat(sharp.height)
        tongues = FlameTongue.row(width: width, height: height, spacing: Self.tongueSpacing * displayScale)
        sparks = (0..<Self.sparkCount).map { _ in
            Spark(
                position: CGPoint(x: .random(in: 0...width), y: .random(in: 0...height)),
                speed: .random(in: 14...34) * displayScale,
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
        // Flames: low while idle, roaring up through the whoosh, sinking
        // back as the words tumble out; every phase eased so nothing snaps.
        let whoosh = progress.map { min(1, $0 / Self.whooshUntil) } ?? 0
        let tumble = progress.map { max(0, ($0 - Self.whooshUntil) / (1 - Self.whooshUntil)) } ?? 0
        let roar = easeInOut(whoosh)
        let dying = easeInOut(min(1, tumble * 1.3))
        let flameScale = (0.55 + 0.9 * roar) * (1 - dying)
        for index in sparks.indices {
            sparks[index].position.y += sparks[index].speed * (1 + CGFloat(whoosh) * 2) * elapsed
            sparks[index].position.x += CGFloat(sin(time * 3 + sparks[index].phase)) * 0.5 * displayScale
            if sparks[index].position.y > height + 4 * displayScale {
                sparks[index].position = CGPoint(x: .random(in: 0...width), y: -2 * displayScale)
            }
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: height)
            cgContext.scaleBy(x: 1, y: -1)
            if tumble > 0 {
                drawTumbling(sharp, in: cgContext, rect: rect, tumble: tumble)
            }
            drawUnderglow(in: cgContext, rect: rect, strength: roar * (1 - dying))
            FlameTongue.draw(tongues, in: cgContext, time: time, base: Self.tongueSpacing * displayScale * 0.9, palette: palette) { _ in
                flameScale
            }
            drawSparks(in: cgContext, time: time, fade: 1 - dying)
            // A soft bell of green light peaking as the flames crest.
            let bell = progress.map { min(1, max(0, ($0 - Self.whooshUntil + 0.2) / 0.4)) } ?? 0
            let flash = CGFloat(pow(sin(bell * .pi), 2))
            drawFlash(in: cgContext, rect: rect, color: palette.outer, alpha: 0.4 * flash)
        }
        layer.contents = image.cgImage
    }

    /// The words rising out of the fire, spun and small at first, green
    /// while they are hot.
    /// The fire's light along the baseline while it roars.
    private func drawUnderglow(in cgContext: CGContext, rect: CGRect, strength: CGFloat) {
        // A band across a page shows the view's edges; the flames carry it there.
        guard strength > 0.01, !isOnLightBackdrop else { return }
        let colors = [palette.outer.withAlphaComponent(0.35 * strength).cgColor, palette.outer.withAlphaComponent(0).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
        cgContext.setBlendMode(glowBlend)
        cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: rect.height * 0.7), options: [])
        cgContext.setBlendMode(.normal)
    }

    private func drawTumbling(_ sharp: CGImage, in cgContext: CGContext, rect: CGRect, tumble: Double) {
        let settle = CGFloat(easeOutBack(tumble))
        // The words fade in out of the fire rather than switching on.
        let emerge = CGFloat(min(1, tumble / 0.3))
        let heat = CGFloat(pow(1 - tumble, 1.5))
        cgContext.saveGState()
        cgContext.setAlpha(emerge)
        cgContext.translateBy(x: rect.midX, y: rect.midY - rect.height * 0.7 * (1 - settle))
        cgContext.rotate(by: -0.12 * (1 - settle))
        cgContext.scaleBy(x: 0.85 + 0.15 * settle, y: 0.85 + 0.15 * settle)
        cgContext.translateBy(x: -rect.midX, y: -rect.midY)
        cgContext.setShadow(offset: .zero, blur: 6 * displayScale, color: palette.outer.withAlphaComponent(heat).cgColor)
        cgContext.draw(sharp, in: rect)
        cgContext.setShadow(offset: .zero, blur: 0, color: nil)
        cgContext.setBlendMode(.sourceAtop)
        cgContext.setFillColor(palette.outer.withAlphaComponent(0.7 * heat).cgColor)
        cgContext.fill(rect)
        cgContext.restoreGState()
    }

    private func drawSparks(in cgContext: CGContext, time: Double, fade: CGFloat) {
        for spark in sparks {
            let glow = CGFloat(0.5 + 0.5 * abs(sin(time * 6 + spark.phase))) * fade
            cgContext.setFillColor(palette.core.withAlphaComponent(glow).cgColor)
            let size = 1.2 * displayScale
            cgContext.fillEllipse(in: CGRect(x: spark.position.x - size, y: spark.position.y - size, width: size * 2, height: size * 2))
        }
    }
}

struct FlooOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        FlooOverlayView(style: style, charRange: charRange)
    }
}
