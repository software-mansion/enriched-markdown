import EnrichedMarkdown
import UIKit

/// Cuts the text into small tiles once and draws them wherever a subclass
/// places them each frame, tinted with the spoiler color while unsettled.
/// `strength` runs 1 while idle and, on reveal, to 0 with a small overshoot
/// past it, so tiles fly home and settle with a bounce.
class TileOverlayView: FrameAnimatedOverlayView {
    /// Uniform random values in 0...1 a subclass turns into its own motion.
    struct Seeds {
        let first = CGFloat.random(in: 0...1)
        let second = CGFloat.random(in: 0...1)
        let third = CGFloat.random(in: 0...1)
    }

    struct Tile {
        let piece: CGImage
        /// Where the tile belongs, in the flipped drawing context.
        let home: CGRect
        let seeds = Seeds()
    }

    /// Tile edge, in points.
    var tileSize: CGFloat = 3
    var tint: UIColor = .secondaryLabel
    private(set) var tiles: [Tile] = []
    private(set) var canvas = CGSize.zero
    private let startTime = CACurrentMediaTime()
    /// Idle motion stops the moment the reveal starts, so a tile's flight
    /// home begins from where it was and nothing jumps mid-flight.
    private var frozenTime: Double?

    /// Where `tile` sits and how far it is turned at this moment.
    func placement(of tile: Tile, time: Double, strength: Double) -> (center: CGPoint, rotation: CGFloat) {
        (CGPoint(x: tile.home.midX, y: tile.home.midY), 0)
    }

    /// How much `tile` is stretched this moment; 1 is its natural size.
    func stretch(of tile: Tile, time: Double, strength: Double) -> CGSize {
        CGSize(width: 1, height: 1)
    }

    /// Anything drawn over the tiles, untinted; `progress` is nil while idle.
    func decorate(in cgContext: CGContext, time: Double, strength: Double, progress: Double?) {}

    override func prepare() {
        guard let image = concealedTextImage().cgImage,
              let data = image.dataProvider?.data as Data?
        else { return }
        canvas = CGSize(width: image.width, height: image.height)
        let edge = Int((tileSize * displayScale).rounded())
        let bytesPerPixel = image.bitsPerPixel / 8

        for top in stride(from: 0, to: image.height, by: edge) {
            for left in stride(from: 0, to: image.width, by: edge) {
                let rect = CGRect(x: left, y: top, width: edge, height: edge)
                    .intersection(CGRect(origin: .zero, size: canvas))
                guard hasInk(data, image: image, in: rect, bytesPerPixel: bytesPerPixel),
                      let piece = image.cropping(to: rect)
                else { continue }
                tiles.append(Tile(
                    piece: piece,
                    home: CGRect(x: rect.minX, y: canvas.height - rect.maxY, width: rect.width, height: rect.height)
                ))
            }
        }
    }

    override func draw(progress: Double?) {
        guard !tiles.isEmpty else { return }
        let strength = progress.map { 1 - easeOutBack($0) } ?? 1
        let elapsed = CACurrentMediaTime() - startTime
        if progress != nil, frozenTime == nil {
            frozenTime = elapsed
        }
        let time = frozenTime ?? elapsed

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: canvas.height)
            cgContext.scaleBy(x: 1, y: -1)
            for tile in tiles {
                let place = placement(of: tile, time: time, strength: strength)
                let size = stretch(of: tile, time: time, strength: strength)
                cgContext.saveGState()
                cgContext.translateBy(x: place.center.x, y: place.center.y)
                cgContext.rotate(by: place.rotation)
                cgContext.scaleBy(x: size.width, y: size.height)
                cgContext.draw(tile.piece, in: CGRect(
                    x: -tile.home.width / 2,
                    y: -tile.home.height / 2,
                    width: tile.home.width,
                    height: tile.home.height
                ))
                cgContext.restoreGState()
            }
            // Loose tiles carry the spoiler color and take the text's own as they land.
            cgContext.setBlendMode(.sourceAtop)
            cgContext.setFillColor(tint.withAlphaComponent(max(0, min(1, strength))).cgColor)
            cgContext.fill(CGRect(origin: .zero, size: canvas))
            cgContext.setBlendMode(.normal)
            decorate(in: cgContext, time: time, strength: strength, progress: progress)
        }
        layer.contents = image.cgImage
    }

    /// Any nonzero byte in a premultiplied bitmap means a visible pixel.
    private func hasInk(_ data: Data, image: CGImage, in rect: CGRect, bytesPerPixel: Int) -> Bool {
        for row in Int(rect.minY)..<Int(rect.maxY) {
            let start = row * image.bytesPerRow + Int(rect.minX) * bytesPerPixel
            let end = start + Int(rect.width) * bytesPerPixel
            if data[start..<end].contains(where: { $0 != 0 }) { return true }
        }
        return false
    }
}
