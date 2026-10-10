import EnrichedMarkdown
import UIKit

/// A Portkey: the line twisted into a travelling helix, every fragment
/// circling its own place with a phase that advances along the line, so
/// the words become a spinning rope of the spoiler color. On reveal the
/// helix unwinds and the fragments settle into the words.
final class PortkeyOverlayView: TileOverlayView {
    /// Orbit radius, in points; the twist's wavelength, in points; and how
    /// fast the rope turns, in radians per second.
    private static let orbit: CGFloat = 8
    private static let wavelength: CGFloat = 34
    private static let turn = 5.0
    private static let flash = UIColor(red: 0.7, green: 0.85, blue: 1, alpha: 1)
    private static let flashUntil = 0.22

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        tint = style.color ?? .secondaryLabel
        idleFramesPerSecond = 24
        revealDuration = 0.9
        lineStagger = 0.4
    }

    override func placement(of tile: Tile, time: Double, strength: Double) -> (center: CGPoint, rotation: CGFloat) {
        let orbit = Self.orbit * displayScale * strength
        let twist = Double(tile.home.midX / (Self.wavelength * displayScale)) * 2 * .pi
        let angle = time * Self.turn + twist + Double(tile.seeds.first) * 0.6
        // The tug: everything jolts as the Portkey takes hold.
        let jolt = strength > 0.85 && strength < 1 ? 2.5 * displayScale : 0
        let center = CGPoint(
            x: tile.home.midX + orbit * 0.6 * CGFloat(cos(angle)) + .random(in: -jolt...jolt),
            y: tile.home.midY + orbit * CGFloat(sin(angle)) + .random(in: -jolt...jolt)
        )
        return (center, CGFloat(angle) * 0.3 * strength)
    }

    override func decorate(in cgContext: CGContext, time: Double, strength: Double, progress: Double?) {
        guard let progress, progress < Self.flashUntil else { return }
        let alpha = CGFloat(1 - progress / Self.flashUntil)
        let flash = highlight(Self.flash, onLight: UIColor(red: 0.3, green: 0.45, blue: 0.85, alpha: 1))
        drawFlash(in: cgContext, rect: CGRect(origin: .zero, size: canvas), color: flash, alpha: 0.45 * alpha)
    }
}

struct PortkeyOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        PortkeyOverlayView(style: style, charRange: charRange)
    }
}
