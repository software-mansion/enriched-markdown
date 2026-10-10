import EnrichedMarkdown
import UIKit

/// The text shattered into small tiles that hang scattered in the spoiler
/// color, drifting and slowly tumbling. On reveal they fly home, overshoot
/// a touch, and settle into the words in the text's own color.
final class ScatterOverlayView: TileOverlayView {
    /// How far a tile flies at full strength, in points.
    private static let spread: CGFloat = 16
    /// Idle float amplitude, in points.
    private static let drift: CGFloat = 2
    private static let maxSpin: CGFloat = .pi * 0.8

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        tint = style.color ?? .secondaryLabel
        idleFramesPerSecond = 20
        revealDuration = 0.9
        lineStagger = 0.4
    }

    override func placement(of tile: Tile, time: Double, strength: Double) -> (center: CGPoint, rotation: CGFloat) {
        let (first, second, third) = (tile.seeds.first, tile.seeds.second, tile.seeds.third)
        let spread = Self.spread * displayScale
        let drift = Self.drift * displayScale
        // A random direction with a lift, like ash; flattened, since the
        // view clips to its line and tall flights would vanish.
        let angle = first * 2 * .pi
        let distance = spread * (0.4 + 0.6 * second)
        let wobble = time * Double(1.5 + 1.5 * third) + Double(first) * 2 * .pi
        let offset = CGVector(
            dx: (cos(angle) * distance + drift * CGFloat(sin(wobble))) * strength,
            dy: (sin(angle) * distance * 0.5 + spread * 0.15 + drift * CGFloat(cos(wobble))) * strength
        )
        let center = CGPoint(x: tile.home.midX + offset.dx, y: tile.home.midY + offset.dy)
        return (center, (third * 2 - 1) * Self.maxSpin * strength)
    }
}

struct ScatterOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        ScatterOverlayView(style: style, charRange: charRange)
    }
}
