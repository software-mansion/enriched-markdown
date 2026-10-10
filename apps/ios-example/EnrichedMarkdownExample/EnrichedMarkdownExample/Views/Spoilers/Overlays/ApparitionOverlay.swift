import EnrichedMarkdown
import UIKit

/// Apparition: the fragments smeared into long streaks whirling along the
/// line under drifting black smoke. On reveal there is a crack of white,
/// everything snaps into the words with an overshoot, and the smoke bursts
/// outward and clears.
final class ApparitionOverlayView: TileOverlayView {
    private static let smoke = UIColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)
    /// Whirl reach in points, the whirl's wavelength in points, its speed
    /// in radians per second, and how far a fragment is smeared.
    private static let reach: CGFloat = 9
    private static let wavelength: CGFloat = 46
    private static let whirl = 4.5
    private static let smear: CGFloat = 3.5
    private static let puffCount = 5
    private static let crackUntil = 0.15

    private let puffSeeds = (0..<5).map { _ in (CGFloat.random(in: 0.1...0.9), CGFloat.random(in: 0.3...0.7), Double.random(in: 0...(2 * .pi))) }

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        tint = style.color ?? .secondaryLabel
        idleFramesPerSecond = 24
        revealDuration = 0.6
        lineStagger = 0.35
    }

    override func placement(of tile: Tile, time: Double, strength: Double) -> (center: CGPoint, rotation: CGFloat) {
        let reach = Self.reach * displayScale * strength
        let phase = Double(tile.home.midX / (Self.wavelength * displayScale)) * 2 * .pi + Double(tile.seeds.first) * 2.6
        let angle = time * Self.whirl + phase
        let center = CGPoint(
            x: tile.home.midX + reach * 1.8 * CGFloat(cos(angle)),
            y: tile.home.midY + reach * CGFloat(sin(angle))
        )
        // Streaks lie along the direction they travel.
        return (center, CGFloat(atan2(cos(angle), -1.8 * sin(angle))) * strength * 0.15)
    }

    override func stretch(of tile: Tile, time: Double, strength: Double) -> CGSize {
        CGSize(width: 1 + Self.smear * (isOnLightBackdrop ? 0.7 : 1) * strength, height: max(0.4, 1 - 0.5 * strength))
    }

    override func decorate(in cgContext: CGContext, time: Double, strength: Double, progress: Double?) {
        let spread = CGFloat(progress.map { min(1, $0 / 0.5) } ?? 0)
        for (index, seed) in puffSeeds.enumerated() {
            let center = CGPoint(
                x: canvas.width * seed.0 + canvas.width * 0.04 * CGFloat(sin(time * 0.6 + seed.2)),
                y: isOnLightBackdrop ? canvas.height / 2 : canvas.height * seed.1 + canvas.height * 0.12 * CGFloat(cos(time * 0.9 + seed.2))
            )
            let radius = canvas.width * 0.1 * (1 + 0.15 * CGFloat(sin(time * 1.3 + Double(index)))) * (1 + 2.5 * spread)
            // Black smoke on a page reads as stains; there the puffs are
            // mist in the spoiler color, part of the streaks.
            let alpha = (isOnLightBackdrop ? 0.22 : 0.7) * (1 - spread)
            guard alpha > 0.01 else { continue }
            let smoke = highlight(Self.smoke, onLight: tint)
            let colors = [smoke.withAlphaComponent(alpha).cgColor, smoke.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { continue }
            // On a page a round puff wider than the line clips into a band
            // with hard edges, so there it is flattened to fit inside.
            let squash = isOnLightBackdrop ? min(1, canvas.height * 0.42 / radius) : 1
            cgContext.saveGState()
            cgContext.translateBy(x: center.x, y: center.y)
            cgContext.scaleBy(x: 1, y: squash)
            cgContext.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: radius, options: [])
            cgContext.restoreGState()
        }
        guard let progress, progress < Self.crackUntil else { return }
        let crack = highlight(.white, onLight: UIColor(red: 0.55, green: 0.6, blue: 0.75, alpha: 1))
        drawFlash(in: cgContext, rect: CGRect(origin: .zero, size: canvas), color: crack, alpha: 0.7 * CGFloat(1 - progress / Self.crackUntil))
    }
}

struct ApparitionOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        ApparitionOverlayView(style: style, charRange: charRange)
    }
}
