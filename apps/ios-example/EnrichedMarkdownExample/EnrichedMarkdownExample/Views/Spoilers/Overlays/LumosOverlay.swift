import EnrichedMarkdown
import UIKit

/// Lumos: shadow clouds drift along the line, dust motes catching the light
/// of a single wand tip that breathes and wanders through them. On reveal
/// the light swells, a bright rim races outward, the clouds burn away and
/// the words appear white-hot inside the bloom before cooling.
final class LumosOverlayView: FrameAnimatedOverlayView {
    private static let dark = UIColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 1)
    private static let shadow = UIColor(red: 0.2, green: 0.13, blue: 0.07, alpha: 1)
    private static let light = UIColor(red: 0.85, green: 0.93, blue: 1, alpha: 1)
    private static let warmLight = UIColor(red: 1, green: 0.9, blue: 0.7, alpha: 1)
    /// Core radius and halo reach of the light, and how far it lights the
    /// dust, in points.
    private static let core: CGFloat = 2.8
    private static let halo: CGFloat = 30
    private static let lightReach: CGFloat = 50
    private static let moteCount = 22
    private static let feather: CGFloat = 40
    /// One shadow cloud per this many points of line.
    private static let cloudSpacing: CGFloat = 22

    private struct Mote {
        var position: CGPoint
        let velocity: CGVector
        let size: CGFloat
        let phase: Double
    }

    private var sharp: CGImage?
    private var origin = CGPoint.zero
    private var motes: [Mote] = []
    private var cloudPhases: [Double] = []
    private let drift = Double.random(in: 0...(2 * .pi))
    private let startTime = CACurrentMediaTime()
    private var lastTime = CACurrentMediaTime()

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        idleFramesPerSecond = 24
        revealDuration = 1.2
        lineStagger = 0.5
    }

    override func prepare() {
        guard let sharp = concealedTextImage().cgImage else { return }
        self.sharp = sharp
        let width = CGFloat(sharp.width)
        let height = CGFloat(sharp.height)
        motes = (0..<Self.moteCount).map { _ in
            Mote(
                position: CGPoint(x: .random(in: 0...width), y: .random(in: 0...height)),
                velocity: CGVector(dx: .random(in: -3...3) * displayScale, dy: .random(in: -2...2) * displayScale),
                size: .random(in: 0.6...1.4) * displayScale,
                phase: .random(in: 0...(2 * .pi))
            )
        }
        let clouds = max(2, Int((width / displayScale / Self.cloudSpacing).rounded(.up)))
        cloudPhases = (0..<clouds).map { _ in .random(in: 0...(2 * .pi)) }
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
        if progress == nil {
            origin = CGPoint(
                x: width * (0.5 + 0.3 * CGFloat(sin(time * 0.35 + drift))),
                y: height * (0.5 + 0.2 * CGFloat(sin(time * 0.55 + drift * 2)))
            )
        }
        advanceMotes(by: elapsed, width: width, height: height)
        let bloom = CGFloat(progress.map { easeInOut($0) } ?? 0)
        let breath = CGFloat(0.9 + 0.1 * sin(time * 2.2))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: height)
            cgContext.scaleBy(x: 1, y: -1)
            drawClouds(in: cgContext, rect: rect, time: time, bloom: bloom)
            if let progress {
                drawLitText(sharp, in: cgContext, rect: rect, progress: progress, bloom: bloom)
                drawRim(in: cgContext, rect: rect, bloom: bloom)
            }
            drawMotes(in: cgContext, time: time, bloom: bloom)
            drawLight(in: cgContext, breath: breath, bloom: bloom, reach: hypot(width, height))
        }
        layer.contents = image.cgImage
    }

    private func advanceMotes(by elapsed: CFTimeInterval, width: CGFloat, height: CGFloat) {
        for index in motes.indices {
            motes[index].position.x += motes[index].velocity.dx * elapsed
            motes[index].position.y += motes[index].velocity.dy * elapsed
            motes[index].position.x = (motes[index].position.x + width).truncatingRemainder(dividingBy: width)
            motes[index].position.y = (motes[index].position.y + height).truncatingRemainder(dividingBy: height)
        }
    }

    /// The dark as drifting, breathing shadow clouds: soft ellipses that
    /// stay inside the line, so there is no sheet with edges. Near the
    /// light they thin, and the bloom burns them away.
    private func drawClouds(in cgContext: CGContext, rect: CGRect, time: Double, bloom: CGFloat) {
        let color = highlight(Self.dark, onLight: Self.shadow)
        let count = cloudPhases.count
        let slot = rect.width / CGFloat(max(count, 1))
        for (index, phase) in cloudPhases.enumerated() {
            let center = CGPoint(
                x: slot * (CGFloat(index) + 0.5) + slot * 0.15 * CGFloat(sin(time * 0.4 + phase)),
                y: rect.midY + rect.height * 0.06 * CGFloat(cos(time * 0.7 + phase))
            )
            let breathe = 1 + 0.08 * CGFloat(sin(time * 0.9 + phase))
            // Wide enough to overlap its neighbours into one bank; only the
            // clouds at the ends fade out early, so nothing is cut flat.
            let radiusX = min(slot * 2.2 * breathe, max(slot, center.x), max(slot, rect.width - center.x))
            let radiusY = rect.height * 0.55 * breathe
            let distance = hypot(center.x - origin.x, center.y - origin.y)
            let lit = max(0, 1 - distance / (Self.lightReach * displayScale * 1.4))
            let alpha = (0.7 - 0.2 * lit) * (1 - bloom)
            guard alpha > 0.01 else { continue }
            let colors = [
                color.withAlphaComponent(alpha).cgColor,
                color.withAlphaComponent(alpha * 0.85).cgColor,
                color.withAlphaComponent(0).cgColor
            ] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1]) else { continue }
            cgContext.saveGState()
            cgContext.translateBy(x: center.x, y: center.y)
            cgContext.scaleBy(x: 1, y: radiusY / radiusX)
            cgContext.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: radiusX, options: [])
            cgContext.restoreGState()
        }
    }

    /// The words inside the circle of light, glowing while it is young.
    private func drawLitText(_ sharp: CGImage, in cgContext: CGContext, rect: CGRect, progress: Double, bloom: CGFloat) {
        let feather = Self.feather * displayScale
        let radius = hypot(rect.width, rect.height) * bloom + feather
        let glow = CGFloat(max(0, 1 - progress / 0.85))
        cgContext.saveGState()
        if let mask = radialMask(size: rect.size, center: origin, radius: radius, feather: feather) {
            cgContext.clip(to: rect, mask: mask)
        }
        cgContext.draw(sharp, in: rect)
        cgContext.setBlendMode(glowBlend)
        cgContext.setAlpha(glow)
        cgContext.setShadow(offset: .zero, blur: 7 * displayScale, color: highlight(Self.light, onLight: Self.warmLight).cgColor)
        cgContext.draw(sharp, in: rect)
        cgContext.restoreGState()
    }

    /// A bright rim on the edge of the bloom as it races outward.
    private func drawRim(in cgContext: CGContext, rect: CGRect, bloom: CGFloat) {
        guard bloom > 0.02, bloom < 0.98 else { return }
        let reach = hypot(rect.width, rect.height) * bloom
        let color = highlight(Self.light, onLight: Self.warmLight)
        cgContext.setBlendMode(glowBlend)
        cgContext.setStrokeColor(color.withAlphaComponent(0.7 * (1 - bloom)).cgColor)
        cgContext.setLineWidth(4 * displayScale)
        cgContext.setShadow(offset: .zero, blur: 6 * displayScale, color: color.cgColor)
        cgContext.strokeEllipse(in: CGRect(x: origin.x - reach, y: origin.y - reach, width: reach * 2, height: reach * 2))
        cgContext.setShadow(offset: .zero, blur: 0, color: nil)
        cgContext.setBlendMode(.normal)
    }

    /// Dust visible only where the light reaches it.
    private func drawMotes(in cgContext: CGContext, time: Double, bloom: CGFloat) {
        let reach = Self.lightReach * displayScale
        let color = highlight(Self.light, onLight: Self.warmLight)
        for mote in motes {
            let distance = hypot(mote.position.x - origin.x, mote.position.y - origin.y)
            let lit = max(bloom, max(0, 1 - distance / reach))
            let twinkle = CGFloat(0.5 + 0.5 * sin(time * 3 + mote.phase))
            let alpha = lit * twinkle * 0.9
            guard alpha > 0.02 else { continue }
            cgContext.setFillColor(color.withAlphaComponent(alpha).cgColor)
            cgContext.fillEllipse(in: CGRect(
                x: mote.position.x - mote.size, y: mote.position.y - mote.size, width: mote.size * 2, height: mote.size * 2
            ))
        }
    }

    /// A white core in a soft halo that swells to fill the line as the
    /// reveal goes, and fades out once the words are lit.
    private func drawLight(in cgContext: CGContext, breath: CGFloat, bloom: CGFloat, reach: CGFloat) {
        let presence = 1 - max(0, (bloom - 0.5) * 2)
        guard presence > 0.01 else { return }
        let tint = highlight(Self.light, onLight: Self.warmLight)
        let halo = Self.halo * displayScale * breath + reach * bloom
        let colors = [
            UIColor.white.withAlphaComponent(presence).cgColor,
            tint.withAlphaComponent(0.6 * presence).cgColor,
            tint.withAlphaComponent(0.14 * presence).cgColor,
            tint.withAlphaComponent(0).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0, Self.core * displayScale / halo, 0.35, 1]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) else { return }
        cgContext.setBlendMode(glowBlend)
        cgContext.drawRadialGradient(gradient, startCenter: origin, startRadius: 0, endCenter: origin, endRadius: halo, options: [])
        cgContext.setBlendMode(.normal)
    }
}

struct LumosOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        LumosOverlayView(style: style, charRange: charRange)
    }
}
