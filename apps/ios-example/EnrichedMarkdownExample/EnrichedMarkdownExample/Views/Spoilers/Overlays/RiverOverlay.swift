import EnrichedMarkdown
import UIKit

/// The text's fragments streaming along the line as a current: each row of
/// tiles flows at its own pace, bobbing, wrapping round when it leaves the
/// far edge, and every tile sits a little off its lane so nothing lines up.
/// On reveal the current stops and every fragment is pulled back into the
/// words, some from the far end of the line.
final class RiverOverlayView: TileOverlayView {
    /// Flow speed range per row, in points per second.
    private static let flow: ClosedRange<CGFloat> = 22...55
    /// Sideways scatter within a lane, in points.
    private static let scatter: CGFloat = 10
    /// Vertical bob, in points.
    private static let bob: CGFloat = 1.5
    private static let maxSpin: CGFloat = .pi * 0.3

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        tint = style.color ?? .secondaryLabel
        idleFramesPerSecond = 24
        revealDuration = 0.9
        lineStagger = 0.4
    }

    override func placement(of tile: Tile, time: Double, strength: Double) -> (center: CGPoint, rotation: CGFloat) {
        let seeds = tile.seeds
        let edge = tile.home.width
        // Rows share a speed, so a lane reads as one current; the row index
        // seeds it, and the second seed nudges the tile within the lane.
        let row = (tile.home.minY / edge).rounded()
        let rowMix = CGFloat(abs(sin(Double(row) * 12.9898)))
        let speed = (Self.flow.lowerBound + (Self.flow.upperBound - Self.flow.lowerBound) * rowMix) * displayScale
        let span = canvas.width + edge * 2
        let travelled = tile.home.midX + (seeds.second * 2 - 1) * Self.scatter * displayScale + CGFloat(time) * speed
        let streamX = travelled.truncatingRemainder(dividingBy: span) - edge
        let bob = Self.bob * displayScale * CGFloat(sin(time * 2.2 + Double(seeds.first) * 2 * .pi))

        let center = CGPoint(
            x: tile.home.midX + (streamX - tile.home.midX) * strength,
            y: tile.home.midY + bob * strength
        )
        return (center, (seeds.third * 2 - 1) * Self.maxSpin * strength)
    }
}

struct RiverOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        RiverOverlayView(style: style, charRange: charRange)
    }
}
