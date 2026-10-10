import CoreText
import EnrichedMarkdown
import UIKit

/// A Howler: a red envelope with a wax seal over the line, breathing under
/// a pulsing red glow and trembling now and then. On reveal it shakes and
/// twists, flushes, then bursts open like a mouth: the halves fly apart,
/// paper shards scatter, sound rings ripple out, and the words shout
/// oversized in glowing red before they settle to normal.
final class HowlerOverlayView: FrameAnimatedOverlayView {
    private static let red = UIColor(red: 0.82, green: 0.14, blue: 0.14, alpha: 1)
    private static let flush = UIColor(red: 1, green: 0.35, blue: 0.22, alpha: 1)
    private static let edge = UIColor(red: 0.55, green: 0.06, blue: 0.08, alpha: 1)
    private static let seal = UIColor(red: 0.45, green: 0.03, blue: 0.06, alpha: 1)
    /// Reveal phases: shaking, opening, shouting.
    private static let shakeUntil = 0.3
    private static let openUntil = 0.55
    private static let shoutScale: CGFloat = 1.22
    private static let shardCount = 16
    private static let ringCount = 3

    /// How the envelope is drawn this frame.
    private struct Envelope {
        var shake: CGFloat = 0
        var twist: CGFloat = 0
        var flush: CGFloat = 0
        var gap: CGFloat = 0
        var breath: CGFloat = 1
        var glow: CGFloat = 0.5
    }

    private struct Shard {
        let origin: CGPoint
        let velocity: CGVector
        let spin: CGFloat
        let size: CGSize
    }

    private var sharp: CGImage?
    /// Pixel columns of the letters, so each can shout on its own.
    private var cells: [CGRect] = []
    private var shards: [Shard] = []
    private let startTime = CACurrentMediaTime()

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        idleFramesPerSecond = 24
        revealDuration = 1.4
        lineStagger = 0.5
    }

    override func prepare() {
        guard let sharp = concealedTextImage().cgImage else { return }
        self.sharp = sharp
        let width = CGFloat(sharp.width)
        let height = CGFloat(sharp.height)
        let line = CTLineCreateWithAttributedString(fontAttributed(concealedText))
        let source = concealedText.string as NSString
        cells = concealedClusters().compactMap { range in
            guard source.substring(with: range).rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
            let start = floor(CTLineGetOffsetForStringIndex(line, range.location, nil) * displayScale)
            let end = ceil(CTLineGetOffsetForStringIndex(line, range.location + range.length, nil) * displayScale)
            return CGRect(x: start, y: 0, width: end - start, height: height)
        }
        shards = (0..<Self.shardCount).map { _ in
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 60...160) * displayScale
            return Shard(
                origin: CGPoint(x: .random(in: 0...width), y: height / 2),
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                spin: .random(in: -6...6),
                size: CGSize(width: .random(in: 2...5) * displayScale, height: .random(in: 1.5...3) * displayScale)
            )
        }
    }

    override func draw(progress: Double?) {
        guard let sharp else { return }
        let time = CACurrentMediaTime() - startTime
        let width = CGFloat(sharp.width)
        let height = CGFloat(sharp.height)
        let rect = CGRect(x: 0, y: 0, width: width, height: height)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: height)
            cgContext.scaleBy(x: 1, y: -1)
            guard let progress else {
                let pulse = CGFloat(0.5 + 0.5 * sin(time * 2.4))
                drawEnvelope(in: cgContext, rect: rect, state: Envelope(
                    shake: idleShake(time: time), breath: 1 + 0.012 * CGFloat(sin(time * 2.4)), glow: 0.35 + 0.35 * pulse
                ))
                return
            }
            let shaking = max(0, 1 - progress / Self.shakeUntil)
            let opening = min(1, max(0, (progress - Self.shakeUntil) / (Self.openUntil - Self.shakeUntil)))
            let sinceOpen = max(0, progress - Self.shakeUntil) * revealDuration
            if progress > Self.shakeUntil {
                drawRings(in: cgContext, rect: rect, sinceOpen: sinceOpen)
                drawShout(sharp, in: cgContext, rect: rect, progress: progress)
                drawShards(in: cgContext, sinceOpen: sinceOpen)
            }
            if opening < 1 {
                drawEnvelope(in: cgContext, rect: rect, state: Envelope(
                    shake: (3 + 4 * shaking) * displayScale * (1 - opening),
                    twist: 0.06 * CGFloat(sin(time * 60)) * CGFloat(1 - opening),
                    flush: CGFloat(min(1, progress / Self.shakeUntil)),
                    gap: easeInOut(opening) * height * 1.2,
                    breath: 1 + 0.05 * CGFloat(1 - shaking),
                    glow: 0.7 + 0.3 * CGFloat(1 - opening)
                ))
            }
        }
        layer.contents = image.cgImage
    }

    /// A tremble that comes in bursts while idle.
    private func idleShake(time: Double) -> CGFloat {
        sin(time * 1.3) > 0.7 ? 1.2 * displayScale : 0
    }

    /// The envelope as two halves split along a wavy mouth line, each moved
    /// `gap` from the middle and fading as it goes, under a red glow.
    private func drawEnvelope(in cgContext: CGContext, rect: CGRect, state: Envelope) {
        let shake = state.shake
        let jitter = CGPoint(x: .random(in: -shake...shake), y: .random(in: -shake...shake))
        let fill = blend(Self.red, Self.flush, by: state.flush)
        let leaving = min(1, state.gap / max(rect.height, 1))
        let glow = state.glow
        let gap = state.gap
        cgContext.saveGState()
        cgContext.translateBy(x: rect.midX + jitter.x, y: rect.midY + jitter.y)
        cgContext.rotate(by: state.twist)
        cgContext.scaleBy(x: state.breath, y: state.breath)
        cgContext.translateBy(x: -rect.midX, y: -rect.midY)
        cgContext.setAlpha(1 - leaving * 0.7)
        for half: CGFloat in [1, -1] {
            cgContext.saveGState()
            // The top tumbles away; the bottom drops like paper.
            cgContext.translateBy(x: 0, y: half == 1 ? gap : -gap * 1.3)
            cgContext.rotate(by: half == 1 ? -0.25 * leaving : 0.1 * leaving)
            let path = mouthPath(rect: rect, half: half)
            cgContext.setShadow(offset: .zero, blur: 8 * displayScale, color: Self.flush.withAlphaComponent(glow).cgColor)
            cgContext.addPath(path)
            cgContext.setFillColor(fill.cgColor)
            cgContext.fillPath()
            cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            cgContext.addPath(path)
            cgContext.setStrokeColor(Self.edge.cgColor)
            cgContext.setLineWidth(displayScale)
            cgContext.strokePath()
            if half == 1 {
                drawFlapAndSeal(in: cgContext, rect: rect)
            }
            cgContext.restoreGState()
        }
        cgContext.restoreGState()
    }

    private func drawFlapAndSeal(in cgContext: CGContext, rect: CGRect) {
        cgContext.setStrokeColor(Self.edge.withAlphaComponent(0.8).cgColor)
        cgContext.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        cgContext.addLine(to: CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.12))
        cgContext.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        cgContext.strokePath()
        let sealRadius = rect.height * 0.16
        let center = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.14)
        cgContext.setFillColor(Self.seal.cgColor)
        cgContext.fillEllipse(in: CGRect(x: center.x - sealRadius, y: center.y - sealRadius, width: sealRadius * 2, height: sealRadius * 2))
        cgContext.setStrokeColor(Self.flush.withAlphaComponent(0.6).cgColor)
        cgContext.setLineWidth(displayScale * 0.8)
        let ring = sealRadius * 0.6
        cgContext.strokeEllipse(in: CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2))
    }

    /// The top (`half` = 1) or bottom half of the envelope with a wavy edge
    /// along the middle, so the split reads as a mouth.
    private func mouthPath(rect: CGRect, half: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let amplitude = rect.height * 0.08
        let waves = max(3, Int(rect.width / (18 * displayScale)))
        let farEdge = half == 1 ? rect.maxY : rect.minY
        path.move(to: CGPoint(x: rect.minX, y: farEdge))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        for wave in 0...waves {
            let crest = rect.midY + (wave.isMultiple(of: 2) ? amplitude : -amplitude)
            path.addLine(to: CGPoint(x: rect.minX + rect.width * CGFloat(wave) / CGFloat(waves), y: crest))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: farEdge))
        path.closeSubpath()
        return path
    }

    /// Sound waves rippling out from the middle as it shouts.
    private func drawRings(in cgContext: CGContext, rect: CGRect, sinceOpen: Double) {
        cgContext.setBlendMode(glowBlend)
        for index in 0..<Self.ringCount {
            let age = sinceOpen - Double(index) * 0.12
            guard age > 0, age < 0.7 else { continue }
            let share = CGFloat(age / 0.7)
            let radiusX = rect.width * 0.1 + rect.width * 0.5 * share
            let radiusY = rect.height * (0.2 + 0.5 * share)
            // Rings spread from the seal.
            let center = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.14)
            cgContext.setStrokeColor(Self.flush.withAlphaComponent(0.7 * (1 - share)).cgColor)
            cgContext.setLineWidth((2.5 - 2 * share) * displayScale)
            cgContext.strokeEllipse(in: CGRect(x: center.x - radiusX, y: center.y - radiusY, width: radiusX * 2, height: radiusY * 2))
        }
        cgContext.setBlendMode(.normal)
    }

    private func drawShards(in cgContext: CGContext, sinceOpen: Double) {
        let gravity = 220 * displayScale
        for shard in shards {
            let age = CGFloat(sinceOpen)
            let alpha = max(0, 1 - age / 0.9)
            guard alpha > 0 else { continue }
            let center = CGPoint(
                x: shard.origin.x + shard.velocity.dx * age,
                y: shard.origin.y + shard.velocity.dy * age - gravity * age * age / 2
            )
            cgContext.saveGState()
            cgContext.translateBy(x: center.x, y: center.y)
            cgContext.rotate(by: shard.spin * age)
            cgContext.setFillColor(Self.red.withAlphaComponent(alpha).cgColor)
            cgContext.fill(CGRect(x: -shard.size.width / 2, y: -shard.size.height / 2, width: shard.size.width, height: shard.size.height))
            cgContext.restoreGState()
        }
    }

    /// The words, oversized and glowing red at first, shrinking and cooling
    /// to normal. The whole line shakes and every letter jitters on its own
    /// while they shout.
    private func drawShout(_ sharp: CGImage, in cgContext: CGContext, rect: CGRect, progress: Double) {
        let shout = CGFloat(max(0, 1 - (progress - Self.shakeUntil) / (1 - Self.shakeUntil)))
        let scale = 1 + (Self.shoutScale - 1) * shout
        let shake = 2.5 * displayScale * shout
        let jitter = 1.2 * displayScale * shout
        cgContext.saveGState()
        cgContext.translateBy(x: rect.midX + .random(in: -shake...shake), y: rect.midY + .random(in: -shake...shake))
        cgContext.scaleBy(x: scale, y: scale)
        cgContext.translateBy(x: -rect.midX, y: -rect.midY)
        cgContext.setShadow(offset: .zero, blur: 6 * displayScale, color: Self.flush.withAlphaComponent(shout).cgColor)
        for cell in cells {
            guard let piece = sharp.cropping(to: cell) else { continue }
            let offset = CGPoint(x: .random(in: -jitter...jitter), y: .random(in: -jitter...jitter))
            cgContext.draw(piece, in: CGRect(x: cell.minX + offset.x, y: offset.y, width: cell.width, height: cell.height))
        }
        cgContext.setShadow(offset: .zero, blur: 0, color: nil)
        cgContext.setBlendMode(.sourceAtop)
        cgContext.setFillColor(Self.flush.withAlphaComponent(shout).cgColor)
        cgContext.fill(rect)
        cgContext.restoreGState()
    }

    /// CoreText lays out with its own font key; UIKit's is not guaranteed.
    private func fontAttributed(_ text: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: text)
        result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let font = value as? UIFont else { return }
            result.addAttribute(NSAttributedString.Key(kCTFontAttributeName as String), value: font, range: range)
        }
        return result
    }

    private func blend(_ from: UIColor, _ target: UIColor, by amount: CGFloat) -> UIColor {
        var red1: CGFloat = 0, green1: CGFloat = 0, blue1: CGFloat = 0, alpha1: CGFloat = 0
        var red2: CGFloat = 0, green2: CGFloat = 0, blue2: CGFloat = 0, alpha2: CGFloat = 0
        from.getRed(&red1, green: &green1, blue: &blue1, alpha: &alpha1)
        target.getRed(&red2, green: &green2, blue: &blue2, alpha: &alpha2)
        return UIColor(
            red: red1 + (red2 - red1) * amount,
            green: green1 + (green2 - green1) * amount,
            blue: blue1 + (blue2 - blue1) * amount,
            alpha: 1
        )
    }
}

struct HowlerOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        HowlerOverlayView(style: style, charRange: charRange)
    }
}
