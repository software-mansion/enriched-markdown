import EnrichedMarkdown
import UIKit

/// A Patronus: silver-blue mist swirling along the line with drifting motes
/// of light, whatever the spoiler color. On reveal the mist streams away to
/// the right and the words shimmer in behind it with a silver glow.
final class PatronusOverlayView: FrameAnimatedOverlayView {
    private static let pale = UIColor(red: 0.78, green: 0.88, blue: 1, alpha: 1)
    private static let deep = UIColor(red: 0.38, green: 0.52, blue: 0.85, alpha: 1)

    /// Pale silver over a dark card, a deep silver-blue on a light page.
    private var silver: UIColor { highlight(Self.pale, onLight: Self.deep) }
    private static let cloudCount = 5
    private static let moteCount = 24
    private static let wispCount = 6
    private static let wispTail = 28
    /// Mote drift, in points per second.
    private static let drift: CGFloat = 8

    private struct Mote {
        var position: CGPoint
        let velocity: CGVector
        let size: CGFloat
        let phase: Double
    }

    private struct Wisp {
        var head: CGPoint
        let speed: CGFloat
        let amplitude: CGFloat
        let wavelength: CGFloat
        let phase: Double
        var tail: [CGPoint] = []
    }

    private var sharp: CGImage?
    private var motes: [Mote] = []
    private var wisps: [Wisp] = []
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
                velocity: CGVector(dx: .random(in: 0.3...1) * Self.drift * displayScale, dy: .random(in: -0.4...0.4) * Self.drift * displayScale),
                size: .random(in: 0.8...2) * displayScale,
                phase: .random(in: 0...(2 * .pi))
            )
        }
        wisps = (0..<Self.wispCount).map { _ in
            Wisp(
                head: CGPoint(x: .random(in: 0...width), y: height / 2),
                speed: .random(in: 30...60) * displayScale,
                amplitude: height * .random(in: 0.15...0.35),
                wavelength: .random(in: 40...80) * displayScale,
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
        let eased = CGFloat(progress.map { easeInOut($0) } ?? 0)
        // The mist rushes off to the right as the reveal goes.
        let rush = eased * width * 1.4
        for index in wisps.indices {
            var wisp = wisps[index]
            wisp.head.x += (wisp.speed + 400 * displayScale * eased) * elapsed
            if wisp.head.x > width + 4 * displayScale {
                wisp.head.x = -4 * displayScale
                wisp.tail = []
            }
            wisp.head.y = height / 2 + wisp.amplitude * CGFloat(sin(Double(wisp.head.x / wisp.wavelength) * 2 * .pi + wisp.phase + time * 0.5))
            wisp.tail.append(wisp.head)
            if wisp.tail.count > Self.wispTail { wisp.tail.removeFirst() }
            wisps[index] = wisp
        }
        for index in motes.indices {
            motes[index].position.x += (motes[index].velocity.dx + 300 * displayScale * eased) * elapsed
            motes[index].position.y += motes[index].velocity.dy * elapsed
            motes[index].position.x = (motes[index].position.x + width).truncatingRemainder(dividingBy: width)
            motes[index].position.y = (motes[index].position.y + height).truncatingRemainder(dividingBy: height)
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: height)
            cgContext.scaleBy(x: 1, y: -1)
            if progress != nil {
                drawShimmeringText(sharp, in: cgContext, rect: rect, eased: eased)
            }
            drawMist(in: cgContext, width: width, height: height, time: time, rush: rush, fade: 1 - eased)
            drawWisps(in: cgContext, fade: 1 - eased)
            drawMotes(in: cgContext, time: time, fade: 1 - eased)
        }
        layer.contents = image.cgImage
    }

    private func drawMist(in cgContext: CGContext, width: CGFloat, height: CGFloat, time: Double, rush: CGFloat, fade: CGFloat) {
        guard fade > 0.01 else { return }
        cgContext.setBlendMode(glowBlend)
        for index in 0..<Self.cloudCount {
            let offset = Double(index) * 1.7
            let share = CGFloat(index) / CGFloat(Self.cloudCount - 1)
            let center = CGPoint(
                x: width * (0.1 + 0.8 * share) + width * 0.06 * CGFloat(sin(time * 0.6 + offset)) + rush,
                y: height / 2 + height * 0.25 * CGFloat(sin(time * 0.9 + offset * 2))
            )
            let radius = width * 0.16 * (1 + 0.2 * CGFloat(sin(time * 0.8 + offset)))
            let colors = [silver.withAlphaComponent(0.22 * fade).cgColor, silver.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { continue }
            cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        }
        cgContext.setBlendMode(.normal)
    }

    /// Ribbons of light: thin and faint at both ends, brightest in the
    /// middle, with no head to them.
    private func drawWisps(in cgContext: CGContext, fade: CGFloat) {
        guard fade > 0.01 else { return }
        cgContext.setBlendMode(glowBlend)
        cgContext.setLineCap(.round)
        for wisp in wisps where wisp.tail.count > 1 {
            for index in 1..<wisp.tail.count {
                let share = CGFloat(index) / CGFloat(wisp.tail.count)
                let profile = CGFloat(sin(Double(share) * .pi))
                cgContext.setStrokeColor(silver.withAlphaComponent(0.45 * profile * fade).cgColor)
                cgContext.setLineWidth((0.4 + 0.8 * profile) * displayScale)
                cgContext.move(to: wisp.tail[index - 1])
                cgContext.addLine(to: wisp.tail[index])
                cgContext.strokePath()
            }
        }
        cgContext.setBlendMode(.normal)
    }

    private func drawMotes(in cgContext: CGContext, time: Double, fade: CGFloat) {
        for mote in motes {
            let twinkle = CGFloat(0.4 + 0.6 * abs(sin(time * 2.5 + mote.phase)))
            cgContext.setFillColor(silver.withAlphaComponent(twinkle * fade).cgColor)
            cgContext.fillEllipse(in: CGRect(
                x: mote.position.x - mote.size, y: mote.position.y - mote.size, width: mote.size * 2, height: mote.size * 2
            ))
        }
    }

    /// The words fading in with a silver glow that fades out.
    private func drawShimmeringText(_ sharp: CGImage, in cgContext: CGContext, rect: CGRect, eased: CGFloat) {
        cgContext.saveGState()
        cgContext.setAlpha(eased)
        cgContext.draw(sharp, in: rect)
        cgContext.setBlendMode(glowBlend)
        cgContext.setAlpha(min(1, eased * 2) * (1 - eased))
        cgContext.setShadow(offset: .zero, blur: 7 * displayScale, color: silver.cgColor)
        cgContext.draw(sharp, in: rect)
        cgContext.restoreGState()
    }
}

struct PatronusOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        PatronusOverlayView(style: style, charRange: charRange)
    }
}
