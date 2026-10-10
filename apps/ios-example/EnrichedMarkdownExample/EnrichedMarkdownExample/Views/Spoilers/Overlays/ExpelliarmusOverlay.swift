import EnrichedMarkdown
import UIKit

/// Expelliarmus: the words held in a grip of red energy, strands wrapping
/// round a dark core that tenses and jitters, sparks crackling off it. On
/// reveal a red bolt streaks in from the left and shatters the grip in its
/// path, the shards blasting off to the right, while the words snap free
/// behind it with a jolt and a red glow that cools.
final class ExpelliarmusOverlayView: FrameAnimatedOverlayView {
    private static let core = UIColor(red: 0.3, green: 0.03, blue: 0.06, alpha: 1)
    private static let red = UIColor(red: 0.95, green: 0.15, blue: 0.15, alpha: 1)
    private static let hot = UIColor(red: 1, green: 0.6, blue: 0.5, alpha: 1)
    /// One core blob per this many points, and one shard per this many.
    private static let blobSpacing: CGFloat = 18
    private static let shardSpacing: CGFloat = 5
    private static let strandCount = 3
    private static let sparkLife = 0.35
    /// The grip flares in warning, then the bolt crosses the line.
    private static let windUpUntil = 0.12
    private static let boltUntil = 0.68
    /// How far ahead of the bolt the strands fray, in points.
    private static let frayReach: CGFloat = 40
    private static let feather: CGFloat = 10
    private static let glowTrail: CGFloat = 60

    /// Where the bolt is this frame.
    private struct Bolt {
        let head: CGFloat
        let feather: CGFloat
        let trail: CGFloat
    }

    private struct Shard {
        var position: CGPoint
        var velocity: CGVector
        let size: CGSize
        var angle: CGFloat
        let spin: CGFloat
        var launched = false
        var age: Double = 0
        /// Strand pieces are bright and thin; core pieces dark.
        let isStrand: Bool
    }

    private struct Spark {
        var position: CGPoint
        let velocity: CGVector
        let born: Double
    }

    private var sharp: CGImage?
    private var blobPhases: [Double] = []
    private var shards: [Shard] = []
    private var sparks: [Spark] = []
    private let startTime = CACurrentMediaTime()
    private var lastTime = CACurrentMediaTime()

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        idleFramesPerSecond = 24
        revealDuration = 1.1
        lineStagger = 0.4
    }

    override func prepare() {
        guard let sharp = concealedTextImage().cgImage else { return }
        self.sharp = sharp
        let width = CGFloat(sharp.width)
        let height = CGFloat(sharp.height)
        let blobs = max(3, Int((width / displayScale / Self.blobSpacing).rounded(.up)))
        blobPhases = (0..<blobs).map { _ in .random(in: 0...(2 * .pi)) }
        let step = Self.shardSpacing * displayScale
        shards = stride(from: step / 2, to: width, by: step).flatMap { across -> [Shard] in
            [0.3, 0.7].map { down in
                Shard(
                    position: CGPoint(
                        x: across + .random(in: -step * 0.3...step * 0.3),
                        y: height * down + .random(in: -height * 0.12...height * 0.12)
                    ),
                    velocity: CGVector(dx: .random(in: 220...420) * displayScale, dy: .random(in: -90...90) * displayScale),
                    size: CGSize(width: .random(in: 2.5...5) * displayScale, height: .random(in: 2...3.5) * displayScale),
                    angle: .random(in: 0...(2 * .pi)),
                    spin: .random(in: -14...14),
                    isStrand: false
                )
            }
        } + stride(from: step, to: width, by: step * 2).map { across in
            Shard(
                position: CGPoint(x: across, y: height * .random(in: 0.3...0.7)),
                velocity: CGVector(dx: .random(in: 260...460) * displayScale, dy: .random(in: -120...120) * displayScale),
                size: CGSize(width: .random(in: 5...9) * displayScale, height: 1.3 * displayScale),
                angle: .random(in: -0.6...0.6),
                spin: .random(in: -10...10),
                isStrand: true
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
        // The bolt's head: parked off the left while idle, past the right
        // with its glow spent by the end.
        let sweep = progress.map { min(1, max(0, ($0 - Self.windUpUntil) / (Self.boltUntil - Self.windUpUntil))) } ?? 0
        let head = progress == nil ? -feather * 2 : -feather + (width + trail + 2 * feather) * easeInOut(sweep)
        let tension = CGFloat(0.5 + 0.5 * sin(time * 2.1))
        // The warning flare: the grip glows and clenches before the bolt.
        let flare = CGFloat(progress.map { min(1, $0 / Self.windUpUntil) } ?? 0)
        advance(by: elapsed, time: time, head: head, width: width, height: height, revealing: progress != nil)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: height)
            cgContext.scaleBy(x: 1, y: -1)
            if progress != nil {
                drawFreedText(sharp, in: cgContext, rect: rect, bolt: Bolt(head: head, feather: feather, trail: trail), time: time)
            }
            cgContext.saveGState()
            if let mask = sweepMask(width: Int(width), head: head, feather: feather, keepsAhead: true) {
                cgContext.clip(to: rect, mask: mask)
            }
            drawGrip(in: cgContext, rect: rect, time: time, tension: max(tension, flare), flare: flare, head: head)
            cgContext.restoreGState()
            drawShards(in: cgContext)
            drawSparks(in: cgContext, time: time)
            if progress != nil, head < width + feather {
                drawBolt(in: cgContext, head: head, height: height, trail: trail)
            }
        }
        layer.contents = image.cgImage
    }

    private func advance(by elapsed: CFTimeInterval, time: Double, head: CGFloat, width: CGFloat, height: CGFloat, revealing: Bool) {
        let gravity = 160 * displayScale
        for index in shards.indices {
            if !shards[index].launched, revealing, shards[index].position.x < head {
                shards[index].launched = true
            }
            guard shards[index].launched else { continue }
            shards[index].age += elapsed
            shards[index].velocity.dy -= gravity * elapsed
            shards[index].position.x += shards[index].velocity.dx * elapsed
            shards[index].position.y += shards[index].velocity.dy * elapsed
            shards[index].angle += shards[index].spin * elapsed
        }
        // Sparks crackle off the grip while idle, and burst off the bolt.
        if !revealing, Double.random(in: 0...1) < 0.35 {
            sparks.append(Spark(
                position: CGPoint(x: .random(in: 0...width), y: height * .random(in: 0.2...0.8)),
                velocity: CGVector(dx: .random(in: -20...20) * displayScale, dy: .random(in: -20...20) * displayScale),
                born: time
            ))
        } else if revealing, head < width {
            for _ in 0..<3 {
                sparks.append(Spark(
                    position: CGPoint(x: max(0, head), y: height * .random(in: 0.1...0.9)),
                    velocity: CGVector(dx: .random(in: 40...120) * displayScale, dy: .random(in: -80...80) * displayScale),
                    born: time
                ))
            }
        }
        for index in sparks.indices {
            sparks[index].position.x += sparks[index].velocity.dx * elapsed
            sparks[index].position.y += sparks[index].velocity.dy * elapsed
        }
        sparks.removeAll { time - $0.born > Self.sparkLife }
    }

    /// The dark core, tightening with the tension and with a constriction
    /// travelling down it, red strands of energy wound round it with
    /// pulses racing along them. Before the bolt it flares; ahead of the
    /// bolt the strands fray and lash.
    private func drawGrip(in cgContext: CGContext, rect: CGRect, time: Double, tension: CGFloat, flare: CGFloat, head: CGFloat) {
        let count = blobPhases.count
        let slot = rect.width / CGFloat(count)
        let jitter = (tension > 0.85 ? 0.8 : 0) * displayScale + 1.2 * displayScale * flare
        let coreColor = flare > 0 ? blend(Self.core, Self.red, by: 0.45 * flare) : Self.core
        for (index, phase) in blobPhases.enumerated() {
            let center = CGPoint(
                x: slot * (CGFloat(index) + 0.5) + .random(in: -jitter...jitter),
                y: rect.midY + rect.height * 0.04 * CGFloat(sin(time * 3 + phase)) + .random(in: -jitter...jitter)
            )
            // A squeeze that runs along the grip like a hand tightening.
            let wave = CGFloat(max(0, sin(Double(center.x / rect.width) * 2 * .pi - time * 1.6)))
            let squeeze = (1 - 0.12 * tension) * (1 - 0.16 * wave)
            let radiusX = min(slot * 2 * squeeze, max(slot * 0.8, center.x), max(slot * 0.8, rect.width - center.x))
            let radiusY = rect.height * 0.46 * squeeze
            let colors = [
                coreColor.withAlphaComponent(0.96).cgColor,
                coreColor.withAlphaComponent(0.9).cgColor,
                coreColor.withAlphaComponent(0).cgColor
            ] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.6, 1]) else { continue }
            cgContext.saveGState()
            cgContext.translateBy(x: center.x, y: center.y)
            cgContext.scaleBy(x: 1, y: radiusY / radiusX)
            cgContext.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: radiusX, options: [])
            cgContext.restoreGState()
        }
        cgContext.setBlendMode(glowBlend)
        cgContext.setLineCap(.round)
        let fray = Self.frayReach * displayScale
        for strand in 0..<Self.strandCount {
            let phase = Double(strand) * 2.1
            let amplitude = rect.height * (0.28 - 0.06 * tension)
            let step = 3 * displayScale
            let points = stride(from: CGFloat(0), through: rect.width, by: step).map { across -> CGPoint in
                let wave = sin(Double(across / (34 * displayScale)) * 2 * .pi + time * 2.6 + phase)
                // Strands lash wildly just ahead of the bolt.
                let lash = 1 + 2.2 * max(0, 1 - abs(across - head) / fray) * CGFloat(abs(sin(time * 40 + phase)))
                return CGPoint(x: across, y: rect.midY + amplitude * CGFloat(wave) * min(lash, 1.6))
            }
            cgContext.setStrokeColor(Self.red.withAlphaComponent(0.35 + 0.3 * flare).cgColor)
            cgContext.setLineWidth((3.2 + 1.5 * flare) * displayScale)
            cgContext.addLines(between: points)
            cgContext.strokePath()
            // The hot line, in segments so pulses can race along it.
            for index in 1..<points.count {
                let pulse = 0.55 + 0.45 * sin(Double(points[index].x / (18 * displayScale)) - time * 9 + phase)
                cgContext.setStrokeColor(Self.hot.withAlphaComponent(CGFloat(pulse) * (0.9 + 0.1 * flare)).cgColor)
                cgContext.setLineWidth((1.1 + 0.5 * CGFloat(pulse) + 0.6 * flare) * displayScale)
                cgContext.move(to: points[index - 1])
                cgContext.addLine(to: points[index])
                cgContext.strokePath()
            }
        }
        cgContext.setBlendMode(.normal)
    }

    private func blend(_ from: UIColor, _ target: UIColor, by amount: CGFloat) -> UIColor {
        var red1: CGFloat = 0, green1: CGFloat = 0, blue1: CGFloat = 0, alpha1: CGFloat = 0
        var red2: CGFloat = 0, green2: CGFloat = 0, blue2: CGFloat = 0, alpha2: CGFloat = 0
        from.getRed(&red1, green: &green1, blue: &blue1, alpha: &alpha1)
        target.getRed(&red2, green: &green2, blue: &blue2, alpha: &alpha2)
        return UIColor(
            red: red1 + (red2 - red1) * amount, green: green1 + (green2 - green1) * amount,
            blue: blue1 + (blue2 - blue1) * amount, alpha: 1
        )
    }

    private func drawShards(in cgContext: CGContext) {
        for shard in shards where shard.launched {
            let alpha = CGFloat(max(0, 1 - shard.age / 0.7))
            guard alpha > 0 else { continue }
            cgContext.saveGState()
            cgContext.translateBy(x: shard.position.x, y: shard.position.y)
            cgContext.rotate(by: shard.angle)
            let box = CGRect(x: -shard.size.width / 2, y: -shard.size.height / 2, width: shard.size.width, height: shard.size.height)
            if shard.isStrand {
                cgContext.setBlendMode(glowBlend)
                cgContext.setFillColor(Self.hot.withAlphaComponent(alpha).cgColor)
                cgContext.fill(box)
                cgContext.setBlendMode(.normal)
            } else {
                cgContext.setFillColor(Self.core.withAlphaComponent(alpha).cgColor)
                cgContext.fill(box)
                cgContext.setFillColor(Self.red.withAlphaComponent(alpha * 0.8).cgColor)
                cgContext.fill(CGRect(x: box.minX, y: shard.size.height * 0.2, width: shard.size.width, height: shard.size.height * 0.3))
            }
            cgContext.restoreGState()
        }
    }

    private func drawSparks(in cgContext: CGContext, time: Double) {
        cgContext.setBlendMode(glowBlend)
        for spark in sparks {
            let alpha = CGFloat(1 - (time - spark.born) / Self.sparkLife)
            cgContext.setFillColor(Self.hot.withAlphaComponent(alpha).cgColor)
            let size = 1.1 * displayScale
            cgContext.fillEllipse(in: CGRect(x: spark.position.x - size, y: spark.position.y - size, width: size * 2, height: size * 2))
        }
        cgContext.setBlendMode(.normal)
    }

    /// The bolt: a white-hot head with a long red tail.
    private func drawBolt(in cgContext: CGContext, head: CGFloat, height: CGFloat, trail: CGFloat) {
        let tail = trail * 0.8
        let colors = [Self.red.withAlphaComponent(0).cgColor, Self.red.withAlphaComponent(0.7).cgColor, UIColor.white.cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.7, 1]) else { return }
        cgContext.saveGState()
        cgContext.setBlendMode(glowBlend)
        cgContext.clip(to: CGRect(x: head - tail, y: height / 2 - 2.5 * displayScale, width: tail, height: 5 * displayScale))
        cgContext.drawLinearGradient(gradient, start: CGPoint(x: head - tail, y: 0), end: CGPoint(x: head, y: 0), options: [])
        cgContext.restoreGState()
        let tip = CGPoint(x: head, y: height / 2)
        let glow = [UIColor.white.cgColor, Self.red.withAlphaComponent(0.8).cgColor, Self.red.withAlphaComponent(0).cgColor] as CFArray
        guard let halo = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glow, locations: [0, 0.3, 1]) else { return }
        cgContext.setBlendMode(glowBlend)
        cgContext.drawRadialGradient(halo, startCenter: tip, startRadius: 0, endCenter: tip, endRadius: 13 * displayScale, options: [])
        cgContext.setBlendMode(.normal)
    }

    /// The words behind the bolt, jolted sideways as they come free and
    /// glowing red for a stretch behind the head.
    private func drawFreedText(_ sharp: CGImage, in cgContext: CGContext, rect: CGRect, bolt: Bolt, time: Double) {
        let jolt = bolt.head < rect.width + bolt.feather ? 1.6 * displayScale * CGFloat(sin(time * 55)) : 0
        cgContext.saveGState()
        if let mask = sweepMask(width: Int(rect.width), head: bolt.head, feather: bolt.feather, keepsAhead: false) {
            cgContext.clip(to: rect, mask: mask)
        }
        cgContext.draw(sharp, in: rect.offsetBy(dx: jolt, dy: 0))
        if let glowMask = sweepMask(width: Int(rect.width), head: bolt.head - bolt.trail, feather: bolt.trail, keepsAhead: true) {
            cgContext.clip(to: rect, mask: glowMask)
        }
        cgContext.setBlendMode(glowBlend)
        cgContext.setShadow(offset: .zero, blur: 6 * displayScale, color: Self.red.cgColor)
        cgContext.draw(sharp, in: rect.offsetBy(dx: jolt, dy: 0))
        cgContext.setShadow(offset: .zero, blur: 0, color: nil)
        cgContext.setBlendMode(.sourceAtop)
        cgContext.setFillColor(Self.red.withAlphaComponent(0.55).cgColor)
        cgContext.fill(rect)
        cgContext.restoreGState()
    }
}

struct ExpelliarmusOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        ExpelliarmusOverlayView(style: style, charRange: charRange)
    }
}
