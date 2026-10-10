import EnrichedMarkdown
import UIKit

/// A Time-Turner: three golden hoops tilted against each other and turning
/// through one another around a tiny hourglass, most of the fragments
/// riding the hoops and the rest drifting as dust, the whole thing ticking
/// forward in half-second steps. A wrapped spoiler gets one pendant, on its
/// first line; the lines below are only the dust spilled beneath it. On
/// reveal the hoops run backwards and fold away as the fragments fly home.
final class TimeTurnerOverlayView: TileOverlayView {
    /// Hoop radii as shares of the line's width and height.
    private static let ringsX: [CGFloat] = [0.2, 0.34, 0.48]
    private static let ringsY: [CGFloat] = [0.2, 0.36, 0.5]
    private static let turns: [Double] = [1.4, -1.0, 0.7]
    /// How fast each hoop tilts through the others, in radians per second.
    private static let tilts: [Double] = [0.9, 0.6, 0.45]
    private static let tick = 0.5
    private static let dustShare: CGFloat = 0.2
    private static let maxSpin: CGFloat = .pi * 0.5
    private static let brightGold = UIColor(red: 1, green: 0.82, blue: 0.4, alpha: 1)
    private static let bronze = UIColor(red: 0.5, green: 0.34, blue: 0.06, alpha: 1)

    /// Bright gold over a dark card; bronze on a page, where gold vanishes.
    private var gold: UIColor { highlight(Self.brightGold, onLight: Self.bronze) }
    private static let darkShade = UIColor(red: 0.45, green: 0.3, blue: 0.05, alpha: 1)
    private static let lightShade = UIColor(red: 0.3, green: 0.18, blue: 0.02, alpha: 1)
    private var shade: UIColor { highlight(Self.darkShade, onLight: Self.lightShade) }

    private let glintPhase = Double.random(in: 0...(2 * .pi))
    private let tiltPhase = Double.random(in: 0...(2 * .pi))

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        // The fragments are the sands of time: gold whatever the theme says.
        tint = highlight(Self.brightGold, onLight: Self.bronze)
        idleFramesPerSecond = 24
        revealDuration = 1
        lineStagger = 0.4
    }

    override func placement(of tile: Tile, time: Double, strength: Double) -> (center: CGPoint, rotation: CGFloat) {
        let seeds = tile.seeds
        let away: CGPoint
        if segmentIndex > 0 || seeds.first < Self.dustShare {
            // Loose dust between the hoops, drifting slowly.
            away = CGPoint(
                x: canvas.width * (0.5 + (seeds.second - 0.5) * 0.9) + 4 * displayScale * CGFloat(sin(time * 0.8 + Double(seeds.third) * 6)),
                y: canvas.height * (0.5 + (seeds.third - 0.5) * 0.8) + 2 * displayScale * CGFloat(cos(time * 1.1 + Double(seeds.second) * 6))
            )
        } else {
            let ring = min(2, Int((seeds.first - Self.dustShare) / (1 - Self.dustShare) * 3))
            let angle = Double(seeds.second) * 2 * .pi + ticked(time) * Self.turns[ring] * (2 * strength - 1)
            away = point(onRing: ring, angle: angle, time: time, strength: strength)
        }
        let center = CGPoint(
            x: tile.home.midX + (away.x - tile.home.midX) * strength,
            y: tile.home.midY + (away.y - tile.home.midY) * strength
        )
        return (center, (seeds.third * 2 - 1) * Self.maxSpin * strength)
    }

    override func decorate(in cgContext: CGContext, time: Double, strength: Double, progress: Double?) {
        guard strength > 0.02, segmentIndex == 0 else { return }
        let fade = CGFloat(min(1, strength))
        cgContext.setBlendMode(glowBlend)
        for ring in Self.ringsX.indices {
            drawHoop(ring, in: cgContext, time: time, strength: strength)
        }
        drawGlint(in: cgContext, time: time, strength: strength)
        drawHourglass(in: cgContext, time: time, fade: fade)
        cgContext.setBlendMode(.normal)
    }

    /// Time that advances in eased half-second steps, like a clock's hand.
    private func ticked(_ time: Double) -> Double {
        let step = (time / Self.tick).rounded(.down)
        let within = time / Self.tick - step
        let eased = within < 0.5 ? 2 * within * within : 1 - pow(-2 * within + 2, 2) / 2
        return (step + eased) * Self.tick
    }

    /// The hoop's tilt: its height squashes toward edge-on and back as it
    /// turns through the others, and it leans a little in the plane.
    private func tilt(of ring: Int, time: Double, strength: Double) -> (squash: CGFloat, lean: CGFloat) {
        let phase = time * Self.tilts[ring] * (2 * strength - 1) + tiltPhase + Double(ring) * 2.1
        // Never fully edge-on, so a hoop always reads as a ring.
        return (CGFloat(0.4 + 0.6 * abs(cos(phase))), CGFloat(0.12 * sin(phase * 0.5)))
    }

    private func point(onRing ring: Int, angle: Double, time: Double, strength: Double) -> CGPoint {
        let (squash, lean) = tilt(of: ring, time: time, strength: strength)
        let local = CGPoint(
            x: canvas.width * Self.ringsX[ring] * CGFloat(cos(angle)),
            y: canvas.height * Self.ringsY[ring] * squash * CGFloat(sin(angle))
        )
        return CGPoint(
            x: canvas.width / 2 + local.x * cos(lean) - local.y * sin(lean),
            y: canvas.height / 2 + local.x * sin(lean) + local.y * cos(lean)
        )
    }

    private func drawHoop(_ ring: Int, in cgContext: CGContext, time: Double, strength: Double) {
        let (squash, lean) = tilt(of: ring, time: time, strength: strength)
        let fade = CGFloat(min(1, strength))
        let radiusX = canvas.width * Self.ringsX[ring] * fade
        let radiusY = canvas.height * Self.ringsY[ring] * squash * fade
        cgContext.saveGState()
        cgContext.translateBy(x: canvas.width / 2, y: canvas.height / 2)
        cgContext.rotate(by: lean)
        // Metal: a dark shade under a bright gold rim.
        let rim = CGRect(x: -radiusX, y: -radiusY, width: radiusX * 2, height: radiusY * 2)
        cgContext.setStrokeColor(shade.withAlphaComponent(0.9 * fade).cgColor)
        cgContext.setLineWidth(2.6 * displayScale)
        cgContext.strokeEllipse(in: rim)
        cgContext.setStrokeColor(gold.withAlphaComponent(0.95 * fade).cgColor)
        cgContext.setLineWidth(1.3 * displayScale)
        cgContext.strokeEllipse(in: rim.offsetBy(dx: 0, dy: 0.6 * displayScale))
        cgContext.restoreGState()
    }

    /// A spark running round the outer hoop, on its own schedule per line.
    private func drawGlint(in cgContext: CGContext, time: Double, strength: Double) {
        let fade = CGFloat(min(1, strength))
        let angle = glintPhase + ticked(time) * Self.turns[2] * (2 * strength - 1)
        let glint = point(onRing: 2, angle: angle, time: time, strength: strength)
        let spark = highlight(.white, onLight: Self.bronze)
        let colors = [spark.withAlphaComponent(fade).cgColor, gold.withAlphaComponent(0).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
        let radius = 6 * displayScale
        cgContext.drawRadialGradient(gradient, startCenter: glint, startRadius: 0, endCenter: glint, endRadius: radius, options: [])
    }

    /// The hourglass at the heart of it, its sand running upward, in a
    /// soft golden glow.
    private func drawHourglass(in cgContext: CGContext, time: Double, fade: CGFloat) {
        let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        let half = canvas.height * 0.42 * fade
        let wide = half * 0.62
        let cycle = CGFloat((time / 4).truncatingRemainder(dividingBy: 1))
        let glowColors = [Self.brightGold.withAlphaComponent(0.55 * fade).cgColor, Self.brightGold.withAlphaComponent(0).cgColor] as CFArray
        if let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0, 1]) {
            cgContext.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: half * 2.4, options: [])
        }
        // The glass: two bulbs pinched at the waist, on a dark shade.
        let outline = CGMutablePath()
        outline.move(to: CGPoint(x: center.x - wide, y: center.y + half))
        outline.addQuadCurve(to: CGPoint(x: center.x, y: center.y), control: CGPoint(x: center.x - wide * 0.1, y: center.y + half * 0.75))
        outline.addQuadCurve(
            to: CGPoint(x: center.x - wide, y: center.y - half), control: CGPoint(x: center.x - wide * 0.1, y: center.y - half * 0.75)
        )
        outline.addLine(to: CGPoint(x: center.x + wide, y: center.y - half))
        outline.addQuadCurve(to: CGPoint(x: center.x, y: center.y), control: CGPoint(x: center.x + wide * 0.1, y: center.y - half * 0.75))
        outline.addQuadCurve(
            to: CGPoint(x: center.x + wide, y: center.y + half), control: CGPoint(x: center.x + wide * 0.1, y: center.y + half * 0.75)
        )
        outline.closeSubpath()
        cgContext.setStrokeColor(shade.withAlphaComponent(0.9 * fade).cgColor)
        cgContext.setLineWidth(2.2 * displayScale)
        cgContext.addPath(outline)
        cgContext.strokePath()
        cgContext.setStrokeColor(gold.withAlphaComponent(0.95 * fade).cgColor)
        cgContext.setLineWidth(displayScale)
        cgContext.addPath(outline)
        cgContext.strokePath()
        // Gold caps top and bottom.
        cgContext.setFillColor(gold.withAlphaComponent(0.95 * fade).cgColor)
        for cap: CGFloat in [half, -half] {
            cgContext.fill(CGRect(x: center.x - wide * 1.15, y: center.y + cap - displayScale, width: wide * 2.3, height: 2 * displayScale))
        }

        // Sand: a triangle filling the top bulb as the cycle runs, draining
        // the bottom. Bright on both backdrops, so it stands out from the hoops.
        cgContext.setFillColor(Self.brightGold.withAlphaComponent(0.95 * fade).cgColor)
        let top = half * cycle
        cgContext.move(to: CGPoint(x: center.x, y: center.y))
        cgContext.addLine(to: CGPoint(x: center.x - wide * cycle, y: center.y + top))
        cgContext.addLine(to: CGPoint(x: center.x + wide * cycle, y: center.y + top))
        cgContext.closePath()
        cgContext.fillPath()
        let bottom = half * (1 - cycle)
        cgContext.move(to: CGPoint(x: center.x - wide, y: center.y - half))
        cgContext.addLine(to: CGPoint(x: center.x + wide, y: center.y - half))
        cgContext.addLine(to: CGPoint(x: center.x + wide * (1 - bottom / half), y: center.y - half + bottom))
        cgContext.addLine(to: CGPoint(x: center.x - wide * (1 - bottom / half), y: center.y - half + bottom))
        cgContext.closePath()
        cgContext.fillPath()
        cgContext.setLineWidth(displayScale * 0.8)
        cgContext.move(to: CGPoint(x: center.x, y: center.y - half * 0.6))
        cgContext.addLine(to: CGPoint(x: center.x, y: center.y + top))
        cgContext.strokePath()
    }
}

struct TimeTurnerOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        TimeTurnerOverlayView(style: style, charRange: charRange)
    }
}
