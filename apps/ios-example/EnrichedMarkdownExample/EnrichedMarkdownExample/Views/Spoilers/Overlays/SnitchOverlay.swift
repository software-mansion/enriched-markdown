import EnrichedMarkdown
import UIKit

/// The Golden Snitch: a gold orb with fluttering wings and a comet-bright
/// head darting about inside a golden haze, dragging a light streak and
/// shedding dust. On reveal it streaks along the line in a burst of dust
/// and the words appear in its wake, glowing gold, before it flies off.
final class SnitchOverlayView: FrameAnimatedOverlayView {
    private static let brightGold = UIColor(red: 1, green: 0.8, blue: 0.35, alpha: 1)
    private static let deepGold = UIColor(red: 0.72, green: 0.52, blue: 0.1, alpha: 1)
    private static let wing = UIColor(red: 1, green: 0.97, blue: 0.85, alpha: 0.9)
    /// Body radius and wing span, in points.
    private static let radius: CGFloat = 3.6
    private static let wingSpan: CGFloat = 7
    /// Idle darting speed, in points per second.
    private static let speed: CGFloat = 140
    private static let streakLength = 18
    private static let dustLife = 0.6
    private static let maxDust = 90
    private static let feather: CGFloat = 10
    private static let glowTrail: CGFloat = 60

    private struct Dust {
        var position: CGPoint
        let velocity: CGVector
        let born: Double
        let size: CGFloat
        /// A few motes near the body burn white.
        let hot: Bool
    }

    /// Bright gold over a dark card, a deeper gold on a light page.
    private var gold: UIColor { highlight(Self.brightGold, onLight: Self.deepGold) }

    private var sharp: CGImage?
    private var position = CGPoint.zero
    private var target = CGPoint.zero
    private var hoverUntil: Double = 0
    /// Pixels per second over the last frame; the wings beat with it.
    private var speedNow: CGFloat = 0
    /// Waypoints of the reveal streak, and how far along it has drawn.
    private var flight: [CGPoint] = []
    private var wakeHead: CGFloat = 0
    private var streak: [CGPoint] = []
    private var dust: [Dust] = []
    private let startTime = CACurrentMediaTime()
    private var lastTime = CACurrentMediaTime()

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        idleFramesPerSecond = 30
        revealDuration = 1.1
        lineStagger = 0.5
    }

    override func prepare() {
        guard let sharp = concealedTextImage().cgImage else { return }
        self.sharp = sharp
        position = CGPoint(x: CGFloat(sharp.width) / 2, y: CGFloat(sharp.height) / 2)
        target = randomTarget(width: CGFloat(sharp.width), height: CGFloat(sharp.height))
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
        let trailLength = Self.glowTrail * displayScale

        let before = position
        if let progress {
            if flight.isEmpty {
                flight = makeFlight(width: width, height: height, feather: feather, trailLength: trailLength)
                wakeHead = -feather
            }
            position = point(alongFlight: progress)
            wakeHead = max(wakeHead, position.x)
        } else {
            dart(by: elapsed, width: width, height: height, time: time)
        }
        speedNow = hypot(position.x - before.x, position.y - before.y) / CGFloat(max(elapsed, 0.001))
        streak.append(position)
        if streak.count > Self.streakLength { streak.removeFirst() }
        shedDust(count: progress == nil ? 2 : 6, time: time, elapsed: elapsed)
        let hazeAlpha = CGFloat(progress.map { 1 - min(1, $0 * 2) } ?? 1)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: height)
            cgContext.scaleBy(x: 1, y: -1)
            drawHaze(in: cgContext, width: width, height: height, time: time, alpha: hazeAlpha)
            if progress != nil {
                drawWake(sharp, in: cgContext, rect: rect, head: wakeHead - Self.radius * displayScale, feather: feather, trailLength: trailLength)
            }
            drawStreak(in: cgContext)
            drawDust(in: cgContext, time: time)
            if position.x < width + Self.wingSpan * 2 * displayScale {
                drawSnitch(in: cgContext, time: time, bright: progress != nil)
            }
        }
        layer.contents = image.cgImage
    }

    /// Darts to a target, slowing as it arrives, hovers there for a beat,
    /// then picks the next one.
    private func dart(by elapsed: CFTimeInterval, width: CGFloat, height: CGFloat, time: Double) {
        if time < hoverUntil {
            position.y += CGFloat(sin(time * 14)) * 0.5 * displayScale
            return
        }
        let delta = CGVector(dx: target.x - position.x, dy: target.y - position.y)
        let distance = hypot(delta.dx, delta.dy)
        if distance < 3 * displayScale {
            hoverUntil = time + .random(in: 0.15...0.45)
            target = randomTarget(width: width, height: height)
            return
        }
        let approach = min(1, max(0.3, distance / (50 * displayScale)))
        let step = min(distance, Self.speed * displayScale * approach * elapsed)
        position.x += delta.dx / distance * step
        position.y += delta.dy / distance * step + CGFloat(sin(time * 20)) * 0.4 * displayScale
    }

    /// In from the left, two sharp turns between the top and bottom of the
    /// line, out past the right edge.
    private func makeFlight(width: CGFloat, height: CGFloat, feather: CGFloat, trailLength: CGFloat) -> [CGPoint] {
        let turns = [0.28, 0.55, 0.8].map { share -> CGPoint in
            CGPoint(x: width * (share + .random(in: -0.05...0.05)), y: height * .random(in: 0.2...0.8))
        }
        return [CGPoint(x: -feather, y: height / 2)] + turns + [CGPoint(x: width + trailLength + feather, y: height / 2)]
    }

    /// A point along the flight for `progress`, easing in and out of every
    /// leg so it darts, checks, and darts again.
    private func point(alongFlight progress: Double) -> CGPoint {
        let legs = max(flight.count - 1, 1)
        let scaled = min(Double(legs) - 0.0001, max(0, progress * Double(legs)))
        let leg = Int(scaled)
        let within = easeInOut(scaled - Double(leg))
        let start = flight[leg], finish = flight[leg + 1]
        return CGPoint(x: start.x + (finish.x - start.x) * within, y: start.y + (finish.y - start.y) * within)
    }

    private func randomTarget(width: CGFloat, height: CGFloat) -> CGPoint {
        let inset = Self.wingSpan * displayScale
        return CGPoint(x: .random(in: inset...(width - inset)), y: .random(in: inset...(max(inset, height - inset))))
    }

    private func shedDust(count: Int, time: Double, elapsed: CFTimeInterval) {
        for _ in 0..<count {
            let speed = CGFloat.random(in: 10...40) * displayScale
            let angle = CGFloat.random(in: 0...(2 * .pi))
            dust.append(Dust(
                position: position,
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                born: time,
                size: .random(in: 0.6...1.6) * displayScale,
                hot: Double.random(in: 0...1) < 0.3
            ))
        }
        for index in dust.indices {
            dust[index].position.x += dust[index].velocity.dx * elapsed
            dust[index].position.y += dust[index].velocity.dy * elapsed
        }
        dust.removeAll { time - $0.born > Self.dustLife }
        if dust.count > Self.maxDust { dust.removeFirst(dust.count - Self.maxDust) }
    }

    /// Soft golden clouds drifting over the hidden words.
    private func drawHaze(in cgContext: CGContext, width: CGFloat, height: CGFloat, time: Double, alpha: CGFloat) {
        guard alpha > 0.01 else { return }
        for index in 0..<3 {
            let offset = Double(index) * 2.1
            let center = CGPoint(
                x: width * (0.2 + 0.3 * CGFloat(index)) + width * 0.08 * CGFloat(sin(time * 0.5 + offset)),
                y: height / 2 + height * 0.2 * CGFloat(cos(time * 0.7 + offset))
            )
            let radius = width * 0.18 * (1 + 0.15 * CGFloat(sin(time * 0.9 + offset)))
            let colors = [gold.withAlphaComponent(0.14 * alpha).cgColor, gold.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { continue }
            cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        }
    }

    /// The words behind the Snitch, with a gold glow that fades with distance.
    private func drawWake(_ sharp: CGImage, in cgContext: CGContext, rect: CGRect, head: CGFloat, feather: CGFloat, trailLength: CGFloat) {
        cgContext.saveGState()
        if let mask = sweepMask(width: Int(rect.width), head: head, feather: feather, keepsAhead: false) {
            cgContext.clip(to: rect, mask: mask)
        }
        cgContext.draw(sharp, in: rect)
        if let glowMask = sweepMask(width: Int(rect.width), head: head - trailLength, feather: trailLength, keepsAhead: true) {
            cgContext.clip(to: rect, mask: glowMask)
        }
        cgContext.setBlendMode(glowBlend)
        cgContext.setShadow(offset: .zero, blur: 6 * displayScale, color: gold.withAlphaComponent(0.9).cgColor)
        cgContext.draw(sharp, in: rect)
        cgContext.restoreGState()
    }

    /// A light streak: the recent path as additive, shrinking discs.
    private func drawStreak(in cgContext: CGContext) {
        let radius = Self.radius * displayScale
        cgContext.setBlendMode(glowBlend)
        for (index, point) in streak.enumerated() {
            let share = CGFloat(index + 1) / CGFloat(streak.count)
            let size = radius * 1.6 * share
            cgContext.setFillColor(gold.withAlphaComponent(0.28 * share).cgColor)
            cgContext.fillEllipse(in: CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size))
        }
        cgContext.setBlendMode(.normal)
    }

    private func drawDust(in cgContext: CGContext, time: Double) {
        for mote in dust {
            let age = (time - mote.born) / Self.dustLife
            let twinkle = 0.5 + 0.5 * abs(sin(time * 30 + Double(mote.size)))
            let alpha = CGFloat((1 - age) * twinkle)
            cgContext.setFillColor((mote.hot ? UIColor.white : gold).withAlphaComponent(alpha).cgColor)
            cgContext.fillEllipse(in: CGRect(
                x: mote.position.x - mote.size, y: mote.position.y - mote.size, width: mote.size * 2, height: mote.size * 2
            ))
        }
    }

    private func drawSnitch(in cgContext: CGContext, time: Double, bright: Bool) {
        let radius = Self.radius * displayScale
        let span = Self.wingSpan * displayScale
        // Wings beat faster the faster it flies, and blur into the motion.
        let pace = Double(min(40, speedNow / displayScale / 8))
        let flutter = CGFloat(abs(sin(time * (20 + pace))))
        let wingAlpha = 0.9 - min(0.35, speedNow / displayScale / 600)

        // The comet head: a soft glow around the body.
        let glowRadius = radius * (bright ? 4.5 : 3)
        let colors = [gold.withAlphaComponent(bright ? 0.9 : 0.55).cgColor, gold.withAlphaComponent(0).cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            cgContext.setBlendMode(glowBlend)
            cgContext.drawRadialGradient(gradient, startCenter: position, startRadius: 0, endCenter: position, endRadius: glowRadius, options: [])
            cgContext.setBlendMode(.normal)
        }

        for side: CGFloat in [-1, 1] {
            cgContext.saveGState()
            cgContext.translateBy(x: position.x + side * radius * 0.9, y: position.y)
            cgContext.rotate(by: side * (-0.35 - 0.5 * flutter))
            cgContext.setFillColor(Self.wing.withAlphaComponent(wingAlpha).cgColor)
            cgContext.fillEllipse(in: CGRect(x: side < 0 ? -span : 0, y: -radius * 0.45, width: span, height: radius * 0.9 * (0.4 + 0.6 * flutter)))
            cgContext.restoreGState()
        }
        cgContext.setFillColor(gold.cgColor)
        cgContext.fillEllipse(in: CGRect(x: position.x - radius, y: position.y - radius, width: radius * 2, height: radius * 2))
        cgContext.setFillColor(UIColor.white.withAlphaComponent(0.85).cgColor)
        cgContext.fillEllipse(in: CGRect(x: position.x - radius * 0.45, y: position.y + radius * 0.1, width: radius * 0.7, height: radius * 0.5))
    }
}

struct SnitchOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        SnitchOverlayView(style: style, charRange: charRange)
    }
}
