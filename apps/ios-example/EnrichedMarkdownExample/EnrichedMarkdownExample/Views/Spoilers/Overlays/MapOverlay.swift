import CoreImage
import EnrichedMarkdown
import UIKit

/// The Marauder's Map: faint corridor lines marching across a blank line
/// while several sets of footprints wander over it in both directions and
/// fade behind their walkers. On reveal ink splashes in at a few spots,
/// spreads as glowing, blurred blots in the spoiler color, and sharpens
/// into the words.
final class MapOverlayView: FrameAnimatedOverlayView {
    private static let walkerCount = 3
    private static let paces: ClosedRange<CGFloat> = 28...50
    private static let stride: CGFloat = 9
    private static let printLife: Double = 2.4
    private static let printSize = CGSize(width: 2.4, height: 3.8)
    private static let corridorCount = 2
    /// Blur of the fresh ink, in points, and the soft edge of each blot.
    private static let inkBlur: CGFloat = 3
    private static let feather: CGFloat = 14
    private static let sourceSpacing: CGFloat = 80
    private static let splashDuration = 0.5
    /// Share of the reveal between one ink source landing and the next.
    private static let sourceStagger = 0.14
    /// How long a walker stops to look at an ink spot.
    private static let pause = 0.45

    private struct Walker {
        var position: CGFloat
        let direction: CGFloat
        let pace: CGFloat
        let lane: CGFloat
        let wobble: Double
        var stepsTaken = 0
        var pauseUntil: Double = 0
        var pausedAt = -1
    }

    private struct Footprint {
        let center: CGPoint
        let born: Double
    }

    private var sharp: CGImage?
    private var ink: CGImage?
    private var tint: UIColor = .secondaryLabel
    private var sources: [CGPoint] = []
    private var corridors: [[CGPoint]] = []
    private var walkers: [Walker] = []
    private var footprints: [Footprint] = []
    private let startTime = CACurrentMediaTime()
    private var lastTime = CACurrentMediaTime()

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        tint = style.color ?? .secondaryLabel
        idleFramesPerSecond = 24
        revealDuration = 1.3
        lineStagger = 0.5
    }

    override func prepare() {
        guard let sharp = concealedTextImage().cgImage else { return }
        self.sharp = sharp
        let width = CGFloat(sharp.width)
        let height = CGFloat(sharp.height)

        if let input = CIImage(image: UIImage(cgImage: sharp)) {
            let blurred = input
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: Self.inkBlur * displayScale])
                .cropped(to: input.extent)
            ink = Self.imageContext.createCGImage(blurred, from: input.extent)
        }

        let count = max(2, Int((width / displayScale / Self.sourceSpacing).rounded(.up)))
        sources = (0..<count).map { index in
            let slot = width / CGFloat(count)
            return CGPoint(x: slot * (CGFloat(index) + .random(in: 0.25...0.75)), y: height * .random(in: 0.3...0.7))
        }
        walkers = (0..<Self.walkerCount).map { index in
            let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            return Walker(
                position: direction > 0 ? -width * CGFloat(index) * 0.4 : width * (1 + CGFloat(index) * 0.4),
                direction: direction,
                pace: .random(in: Self.paces) * displayScale,
                lane: height * .random(in: 0.3...0.7),
                wobble: .random(in: 0...(2 * .pi))
            )
        }
        corridors = (0..<Self.corridorCount).map { _ in
            let points = 6
            return (0...points).map { index in
                CGPoint(x: width * CGFloat(index) / CGFloat(points), y: height * .random(in: 0.15...0.85))
            }
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
        if progress == nil {
            walk(by: elapsed, width: width, height: height, time: time)
        }
        let mapFade = CGFloat(progress.map { 1 - min(1, $0 * 2.5) } ?? 1)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: height)
            cgContext.scaleBy(x: 1, y: -1)
            if mapFade > 0 {
                drawCorridors(in: cgContext, time: time, alpha: 0.2 * mapFade)
                drawFootprints(in: cgContext, time: time, alpha: mapFade)
            }
            if let progress, let ink {
                drawSplashes(in: cgContext, progress: progress)
                drawInk(sharp: sharp, ink: ink, in: cgContext, rect: rect, progress: progress)
            }
        }
        layer.contents = image.cgImage
    }

    private func walk(by elapsed: CFTimeInterval, width: CGFloat, height: CGFloat, time: Double) {
        let stride = Self.stride * displayScale
        for index in walkers.indices {
            var walker = walkers[index]
            if time < walker.pauseUntil {
                continue
            }
            // Stop for a beat at an ink spot, once per crossing.
            if let spot = sources.indices.first(where: { $0 != walker.pausedAt && abs(sources[$0].x - walker.position) < stride / 2 }) {
                walker.pausedAt = spot
                walker.pauseUntil = time + Self.pause
                walkers[index] = walker
                continue
            }
            walker.position += walker.pace * walker.direction * elapsed
            if walker.direction > 0, walker.position > width + stride * 2 {
                walker.position = -stride * 2
                walker.stepsTaken = 0
                walker.pausedAt = -1
            } else if walker.direction < 0, walker.position < -stride * 2 {
                walker.position = width + stride * 2
                walker.stepsTaken = 0
                walker.pausedAt = -1
            }
            let travelled = walker.direction > 0 ? walker.position + stride * 2 : width + stride * 2 - walker.position
            let dueSteps = Int((travelled / stride).rounded(.down))
            while walker.stepsTaken < dueSteps {
                walker.stepsTaken += 1
                let side: CGFloat = walker.stepsTaken.isMultiple(of: 2) ? 1 : -1
                let laneY = walker.lane + height * 0.12 * CGFloat(sin(time * 0.7 + walker.wobble))
                footprints.append(Footprint(center: CGPoint(x: walker.position, y: laneY + side * 3.2 * displayScale), born: time))
            }
            walkers[index] = walker
        }
        footprints.removeAll { time - $0.born > Self.printLife }
    }

    /// Dashed floor-plan lines whose dashes creep along.
    private func drawCorridors(in cgContext: CGContext, time: Double, alpha: CGFloat) {
        cgContext.setStrokeColor(tint.withAlphaComponent(alpha).cgColor)
        cgContext.setLineWidth(displayScale)
        cgContext.setLineDash(phase: CGFloat(time * 6) * displayScale, lengths: [3 * displayScale, 4 * displayScale])
        for corridor in corridors {
            guard let first = corridor.first else { continue }
            cgContext.move(to: first)
            for point in corridor.dropFirst() {
                cgContext.addLine(to: point)
            }
            cgContext.strokePath()
        }
        cgContext.setLineDash(phase: 0, lengths: [])
    }

    private func drawFootprints(in cgContext: CGContext, time: Double, alpha fade: CGFloat) {
        let size = CGSize(width: Self.printSize.width * displayScale, height: Self.printSize.height * displayScale)
        for print in footprints {
            let age = (time - print.born) / Self.printLife
            let alpha = CGFloat(1 - age) * 0.85 * fade
            guard alpha > 0.01 else { continue }
            cgContext.setFillColor(tint.withAlphaComponent(alpha).cgColor)
            cgContext.fillEllipse(in: CGRect(
                x: print.center.x - size.width / 2, y: print.center.y - size.height / 2, width: size.width, height: size.height
            ))
            cgContext.fillEllipse(in: CGRect(
                x: print.center.x + size.width * 0.25, y: print.center.y + size.height * 0.45,
                width: size.width * 0.5, height: size.width * 0.5
            ))
        }
    }

    /// When, as a share of the reveal, this source's ink lands.
    private func landing(of index: Int) -> Double {
        Double(index) * Self.sourceStagger
    }

    /// A drop falling in and a ring bursting out of each source as its ink
    /// lands, one source after another.
    private func drawSplashes(in cgContext: CGContext, progress: Double) {
        for (index, source) in sources.enumerated() {
            let life = (progress - landing(of: index)) * revealDuration / Self.splashDuration
            guard life > 0, life < 1 else { continue }
            let drop = CGFloat(min(1, life / 0.3)) * 3 * displayScale
            cgContext.setFillColor(tint.withAlphaComponent(CGFloat(1 - life)).cgColor)
            cgContext.fillEllipse(in: CGRect(x: source.x - drop, y: source.y - drop, width: drop * 2, height: drop * 2))
            let radius = CGFloat(life) * 26 * displayScale
            cgContext.setStrokeColor(tint.withAlphaComponent(CGFloat(1 - life)).cgColor)
            cgContext.setLineWidth((1 + 2 * CGFloat(1 - life)) * displayScale)
            cgContext.strokeEllipse(in: CGRect(x: source.x - radius, y: source.y - radius * 0.6, width: radius * 2, height: radius * 1.2))
        }
    }

    /// Ink blots growing from each source; fresh ink is the blurred, tinted,
    /// glowing text and crossfades to the sharp text as it spreads.
    private func drawInk(sharp: CGImage, ink: CGImage, in cgContext: CGContext, rect: CGRect, progress: Double) {
        let spacing = rect.width / CGFloat(max(sources.count, 1))
        let feather = Self.feather * displayScale
        let reach = spacing * 1.3 + feather
        let radii = sources.indices.map { index -> CGFloat in
            let start = landing(of: index)
            return easeInOut(max(0, (progress - start) / (1 - start))) * reach
        }
        let sharpness = CGFloat(max(0, (progress - 0.5) / 0.5))
        cgContext.saveGState()
        if let mask = blotMask(size: rect.size, radii: radii, feather: feather) {
            cgContext.clip(to: rect, mask: mask)
        }
        cgContext.setAlpha(1 - sharpness)
        cgContext.setShadow(offset: .zero, blur: 5 * displayScale, color: tint.withAlphaComponent(0.8).cgColor)
        cgContext.draw(ink, in: rect)
        cgContext.setShadow(offset: .zero, blur: 0, color: nil)
        cgContext.setBlendMode(.sourceAtop)
        cgContext.setFillColor(tint.withAlphaComponent(1 - sharpness).cgColor)
        cgContext.fill(rect)
        cgContext.setBlendMode(.normal)
        cgContext.setAlpha(sharpness)
        cgContext.draw(sharp, in: rect)
        cgContext.restoreGState()
    }

    /// Gray mask: white inside the growing blots, feathered at their rims.
    private func blotMask(size: CGSize, radii: [CGFloat], feather: CGFloat) -> CGImage? {
        let width = Int(size.width), height = Int(size.height)
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(origin: .zero, size: size))
        let colors = [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 1), CGColor(gray: 0, alpha: 1)] as CFArray
        context.setBlendMode(.lighten)
        for (source, radius) in zip(sources, radii) where radius > 0 {
            let inner = max(0, (radius - feather) / radius)
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(), colors: colors, locations: [0, inner, 1]) else { continue }
            context.drawRadialGradient(gradient, startCenter: source, startRadius: 0, endCenter: source, endRadius: radius, options: [])
        }
        return context.makeImage()
    }
}

struct MapOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        MapOverlayView(style: style, charRange: charRange)
    }
}
