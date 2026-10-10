import CoreText
import EnrichedMarkdown
import UIKit

/// Riddikulus: a boggart squats on the line, a dark shape-shifting mass
/// with wisps curling off its back and two glowing eyes that glance about,
/// narrow, and blink. On reveal it sucks in a breath, flashes a jagged
/// grin, and pops into a puff of smoke and a shower of jester confetti and
/// streamers, and the words bounce in one letter at a time in jester
/// colors, wobbling with laughter before they settle.
final class RiddikulusOverlayView: FrameAnimatedOverlayView {
    private static let body = UIColor(red: 0.12, green: 0.06, blue: 0.18, alpha: 1)
    private static let eye = UIColor(red: 1, green: 0.9, blue: 0.35, alpha: 1)
    private static let confettiColors = [
        UIColor(red: 0.95, green: 0.25, blue: 0.3, alpha: 1),
        UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1),
        UIColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1),
        UIColor(red: 0.3, green: 0.6, blue: 1, alpha: 1),
        UIColor(red: 0.75, green: 0.4, blue: 0.95, alpha: 1),
        UIColor(red: 1, green: 0.55, blue: 0.2, alpha: 1)
    ]
    /// One body blob per this many points of line.
    private static let blobSpacing: CGFloat = 20
    private static let confettiPerBlob = 5
    /// Reveal phases: the breath in, then the pop.
    private static let popAt = 0.18
    private static let blinkEvery = 3.2
    private static let wispCount = 5
    private static let streamerCount = 6
    private static let puffFor = 0.35

    private struct Confetti {
        var position: CGPoint
        var velocity: CGVector
        let color: UIColor
        let size: CGSize
        let spin: CGFloat
        var angle: CGFloat
        /// Streamers are long and curl as they fall.
        let isStreamer: Bool
    }

    private struct Wisp {
        let across: CGFloat
        let phase: Double
        let rate: Double
        let height: CGFloat
    }

    private var sharp: CGImage?
    private var cells: [CGRect] = []
    private var blobPhases: [Double] = []
    private var confetti: [Confetti] = []
    private var wisps: [Wisp] = []
    private var popped = false
    private var popTime: Double = 0
    private var letterColors: [UIColor] = []
    private let eyeDrift = Double.random(in: 0...(2 * .pi))
    private let startTime = CACurrentMediaTime()
    private var lastTime = CACurrentMediaTime()

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        idleFramesPerSecond = 24
        revealDuration = 1.4
        lineStagger = 0.45
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
        let blobs = max(3, Int((width / displayScale / Self.blobSpacing).rounded(.up)))
        blobPhases = (0..<blobs).map { _ in .random(in: 0...(2 * .pi)) }
        wisps = (0..<Self.wispCount).map { _ in
            Wisp(across: .random(in: 0.1...0.9), phase: .random(in: 0...(2 * .pi)), rate: .random(in: 0.7...1.3), height: .random(in: 0.5...0.9))
        }
        letterColors = cells.map { _ in Self.confettiColors.randomElement() ?? .white }
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
        let breath = CGFloat(progress.map { min(1, $0 / Self.popAt) } ?? 0)
        let laugh = progress.map { max(0, ($0 - Self.popAt) / (1 - Self.popAt)) } ?? 0
        if let progress, progress >= Self.popAt, !popped {
            popped = true
            popTime = time
            pop(width: width, height: height)
        }
        advanceConfetti(by: elapsed, height: height)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: height)
            cgContext.scaleBy(x: 1, y: -1)
            if laugh > 0 {
                drawLaughingText(sharp, in: cgContext, rect: rect, laugh: laugh)
            }
            if !popped {
                drawWisps(in: cgContext, rect: rect, time: time, breath: breath)
                drawBoggart(in: cgContext, rect: rect, time: time, breath: breath)
            } else {
                drawPuff(in: cgContext, rect: rect, since: time - popTime)
            }
            drawConfetti(in: cgContext)
        }
        layer.contents = image.cgImage
    }

    /// Overlapping blobs that wobble and breathe, swelling and tightening
    /// as it draws breath before the pop, with two eyes drifting over them.
    private func drawBoggart(in cgContext: CGContext, rect: CGRect, time: Double, breath: CGFloat) {
        let count = blobPhases.count
        let slot = rect.width / CGFloat(count)
        let swell = 1 + 0.25 * breath
        for (index, phase) in blobPhases.enumerated() {
            let center = CGPoint(
                x: slot * (CGFloat(index) + 0.5) + slot * 0.2 * CGFloat(sin(time * 1.1 + phase)),
                y: rect.midY + rect.height * 0.1 * CGFloat(cos(time * 1.6 + phase))
            )
            let wobble = 1 + 0.12 * CGFloat(sin(time * 2.3 + phase))
            let radiusX = min(slot * 1.9 * wobble * swell, max(slot * 0.8, center.x), max(slot * 0.8, rect.width - center.x))
            let radiusY = rect.height * 0.48 * wobble * swell
            let colors = [
                Self.body.withAlphaComponent(0.96).cgColor,
                Self.body.withAlphaComponent(0.9).cgColor,
                Self.body.withAlphaComponent(0).cgColor
            ] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.6, 1]) else { continue }
            cgContext.saveGState()
            cgContext.translateBy(x: center.x, y: center.y)
            cgContext.scaleBy(x: 1, y: radiusY / radiusX)
            cgContext.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: radiusX, options: [])
            cgContext.restoreGState()
        }
        drawEyes(in: cgContext, rect: rect, time: time, breath: breath)
        drawGrin(in: cgContext, rect: rect, time: time, breath: breath)
    }

    /// Dark tendrils curling up off the body and fading, stirred faster as
    /// it draws breath.
    private func drawWisps(in cgContext: CGContext, rect: CGRect, time: Double, breath: CGFloat) {
        cgContext.setLineCap(.round)
        for wisp in wisps {
            let sway = CGFloat(sin(time * wisp.rate * (1 + Double(breath) * 2) + wisp.phase))
            let root = CGPoint(x: rect.width * wisp.across, y: rect.midY)
            let tip = CGPoint(x: root.x + 8 * displayScale * sway, y: rect.height * (0.5 + 0.5 * wisp.height))
            let control = CGPoint(x: root.x - 6 * displayScale * sway, y: rect.height * 0.8)
            for (width, alpha) in [(3.5, 0.25), (1.5, 0.6)] as [(CGFloat, CGFloat)] {
                cgContext.setStrokeColor(Self.body.withAlphaComponent(alpha).cgColor)
                cgContext.setLineWidth(width * displayScale)
                cgContext.move(to: root)
                cgContext.addQuadCurve(to: tip, control: control)
                cgContext.strokePath()
            }
        }
    }

    /// A jagged grin under the eyes, flashed on the breath in.
    private func drawGrin(in cgContext: CGContext, rect: CGRect, time: Double, breath: CGFloat) {
        guard breath > 0.05 else { return }
        let center = eyeCenter(rect: rect, time: time)
        let halfWidth = rect.height * 0.42 * breath
        let mouthY = center.y - rect.height * 0.22
        let teeth = 7
        let path = CGMutablePath()
        path.move(to: CGPoint(x: center.x - halfWidth, y: mouthY + rect.height * 0.05))
        for tooth in 0...teeth {
            let along = CGFloat(tooth) / CGFloat(teeth)
            let dip = tooth.isMultiple(of: 2) ? 0 : rect.height * 0.12 * breath
            path.addLine(to: CGPoint(x: center.x - halfWidth + halfWidth * 2 * along, y: mouthY - dip))
        }
        path.addLine(to: CGPoint(x: center.x + halfWidth, y: mouthY + rect.height * 0.05))
        path.closeSubpath()
        cgContext.addPath(path)
        cgContext.setFillColor(UIColor.white.withAlphaComponent(0.92).cgColor)
        cgContext.fillPath()
    }

    private func eyeCenter(rect: CGRect, time: Double) -> CGPoint {
        CGPoint(
            x: rect.midX + rect.width * 0.18 * CGFloat(sin(time * 0.5 + eyeDrift)),
            y: rect.midY + rect.height * 0.12 * CGFloat(cos(time * 0.8 + eyeDrift))
        )
    }

    /// A ring of smoke bursting outward where the boggart was.
    private func drawPuff(in cgContext: CGContext, rect: CGRect, since: Double) {
        let share = CGFloat(min(1, since / Self.puffFor))
        guard share < 1 else { return }
        let radiusX = rect.width * (0.15 + 0.45 * share)
        let radiusY = rect.height * (0.3 + 0.4 * share)
        cgContext.setStrokeColor(Self.body.withAlphaComponent(0.6 * (1 - share)).cgColor)
        cgContext.setLineWidth((6 - 4 * share) * displayScale)
        cgContext.strokeEllipse(in: CGRect(x: rect.midX - radiusX, y: rect.midY - radiusY, width: radiusX * 2, height: radiusY * 2))
    }

    /// Two eyes that glance from side to side, narrow now and then, and
    /// blink, widening as it draws breath.
    private func drawEyes(in cgContext: CGContext, rect: CGRect, time: Double, breath: CGFloat) {
        let center = eyeCenter(rect: rect, time: time)
        let gap = rect.height * 0.28
        let blinkPhase = (time / Self.blinkEvery).truncatingRemainder(dividingBy: 1)
        let blink = blinkPhase > 0.93 ? CGFloat(1 - abs(blinkPhase - 0.965) / 0.035) : 0
        // Narrowing: a slow squint that comes and goes, gone when it gasps.
        let squint = max(0, CGFloat(sin(time * 0.6 + eyeDrift * 3))) * 0.55 * (1 - breath)
        let open = max(0.08, (1 - blink) * (1 - squint) * (1 + 0.6 * breath))
        let glance = CGFloat(sin(time * 1.3 + eyeDrift)) * 0.5
        let radius = rect.height * 0.11
        for side: CGFloat in [-1, 1] {
            let eye = CGPoint(x: center.x + side * gap, y: center.y)
            cgContext.setFillColor(Self.eye.cgColor)
            cgContext.fillEllipse(in: CGRect(x: eye.x - radius, y: eye.y - radius * open, width: radius * 2, height: radius * 2 * open))
            cgContext.setFillColor(Self.body.cgColor)
            let pupil = radius * 0.45
            let pupilRect = CGRect(x: eye.x - pupil + radius * 0.5 * glance, y: eye.y - pupil * open, width: pupil * 2, height: pupil * 2 * open)
            cgContext.fillEllipse(in: pupilRect)
            cgContext.setFillColor(UIColor.white.withAlphaComponent(0.8 * open).cgColor)
            let glint = radius * 0.22
            cgContext.fillEllipse(in: CGRect(x: eye.x - radius * 0.45, y: eye.y + radius * 0.3 * open, width: glint, height: glint))
        }
    }

    /// The boggart bursts into confetti, a handful of pieces per blob.
    private func pop(width: CGFloat, height: CGFloat) {
        let count = blobPhases.count
        let slot = width / CGFloat(count)
        for index in 0..<count {
            for _ in 0..<Self.confettiPerBlob {
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let speed = CGFloat.random(in: 60...170) * displayScale
                confetti.append(Confetti(
                    position: CGPoint(x: slot * (CGFloat(index) + .random(in: 0.2...0.8)), y: height * .random(in: 0.3...0.7)),
                    velocity: CGVector(dx: cos(angle) * speed, dy: abs(sin(angle)) * speed + 40 * displayScale),
                    color: Self.confettiColors.randomElement() ?? .white,
                    size: CGSize(width: .random(in: 2.5...4.5) * displayScale, height: .random(in: 1.5...2.5) * displayScale),
                    spin: .random(in: -9...9),
                    angle: .random(in: 0...(2 * .pi)),
                    isStreamer: false
                ))
            }
        }
        for _ in 0..<Self.streamerCount {
            let angle = CGFloat.random(in: 0.3...(.pi - 0.3))
            let speed = CGFloat.random(in: 90...160) * displayScale
            confetti.append(Confetti(
                position: CGPoint(x: width * .random(in: 0.2...0.8), y: height / 2),
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed + 60 * displayScale),
                color: Self.confettiColors.randomElement() ?? .white,
                size: CGSize(width: .random(in: 9...14) * displayScale, height: 1.4 * displayScale),
                spin: .random(in: -4...4),
                angle: .random(in: 0...(2 * .pi)),
                isStreamer: true
            ))
        }
    }

    private func advanceConfetti(by elapsed: CFTimeInterval, height: CGFloat) {
        let gravity = 260 * displayScale
        for index in confetti.indices {
            confetti[index].velocity.dy -= gravity * elapsed
            confetti[index].velocity.dx *= 0.985
            confetti[index].position.x += confetti[index].velocity.dx * elapsed
            confetti[index].position.y += confetti[index].velocity.dy * elapsed
            confetti[index].angle += confetti[index].spin * elapsed
        }
        confetti.removeAll { $0.position.y < -8 * displayScale }
    }

    private func drawConfetti(in cgContext: CGContext) {
        for piece in confetti {
            cgContext.saveGState()
            cgContext.translateBy(x: piece.position.x, y: piece.position.y)
            cgContext.rotate(by: piece.angle)
            cgContext.setFillColor(piece.color.cgColor)
            if piece.isStreamer {
                // A curling ribbon.
                let path = CGMutablePath()
                let half = piece.size.width / 2
                path.move(to: CGPoint(x: -half, y: 0))
                path.addQuadCurve(to: CGPoint(x: half, y: 0), control: CGPoint(x: 0, y: piece.size.width * 0.4 * sin(piece.angle * 2)))
                cgContext.addPath(path)
                cgContext.setStrokeColor(piece.color.cgColor)
                cgContext.setLineWidth(piece.size.height)
                cgContext.setLineCap(.round)
                cgContext.strokePath()
            } else {
                // A flat piece seen edge-on as it tumbles.
                cgContext.scaleBy(x: 1, y: max(0.15, abs(cos(piece.angle * 1.7))))
                cgContext.fill(CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2, width: piece.size.width, height: piece.size.height))
            }
            cgContext.restoreGState()
        }
    }

    /// The words bouncing in one letter at a time with overshoot, each
    /// wobbling like a laugh that dies down.
    private func drawLaughingText(_ sharp: CGImage, in cgContext: CGContext, rect: CGRect, laugh: Double) {
        let count = max(1, Double(cells.count))
        for (index, cell) in cells.enumerated() {
            let start = 0.55 * Double(index) / count
            let share = min(1, max(0, (laugh - start) / 0.4))
            guard share > 0, let piece = sharp.cropping(to: cell) else { continue }
            let scale = CGFloat(easeOutBack(share))
            let giggle = CGFloat(sin(laugh * 28 + Double(index))) * 0.1 * CGFloat(1 - share)
            let lift = rect.height * 0.35 * CGFloat(1 - share)
            cgContext.saveGState()
            cgContext.translateBy(x: cell.midX, y: rect.midY + lift)
            cgContext.rotate(by: giggle)
            cgContext.scaleBy(x: scale, y: scale)
            let box = CGRect(x: -cell.width / 2, y: -rect.height / 2, width: cell.width, height: rect.height)
            cgContext.draw(piece, in: box)
            // Lands in a jester color and cools to the text's own.
            cgContext.setBlendMode(.sourceAtop)
            cgContext.setFillColor(letterColors[index].withAlphaComponent(CGFloat(1 - share) * 0.9).cgColor)
            cgContext.fill(box)
            cgContext.restoreGState()
        }
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
}

struct RiddikulusOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        RiddikulusOverlayView(style: style, charRange: charRange)
    }
}
