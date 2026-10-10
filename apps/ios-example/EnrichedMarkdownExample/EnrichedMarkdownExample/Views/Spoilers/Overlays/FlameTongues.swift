import UIKit

/// The two colors of a fire: the tongue and the brighter core inside it.
struct FlamePalette {
    let outer: UIColor
    let core: UIColor
    /// Additive on a dark backdrop, plain on a light one.
    var blend: CGBlendMode = .plusLighter
}

/// Tongues of flame along a baseline, shared by the fire effects.
struct FlameTongue {
    let position: CGFloat
    let height: CGFloat
    let phase: Double
    let rate: Double

    /// One tongue per `spacing` pixels across `width`, up to `height` tall.
    static func row(width: CGFloat, height: CGFloat, spacing: CGFloat) -> [FlameTongue] {
        stride(from: spacing / 2, to: width, by: spacing).map { position in
            FlameTongue(
                position: position + .random(in: -spacing * 0.3...spacing * 0.3),
                height: height * .random(in: 0.45...0.95),
                phase: .random(in: 0...(2 * .pi)),
                rate: .random(in: 6...11)
            )
        }
    }

    /// Draws the tongues flickering, each scaled by `heightScale` of its
    /// position, additively, in the palette's colors.
    static func draw(
        _ tongues: [FlameTongue], in cgContext: CGContext, time: Double, base: CGFloat,
        palette: FlamePalette, heightScale: (CGFloat) -> CGFloat
    ) {
        cgContext.setBlendMode(palette.blend)
        for tongue in tongues {
            let flicker = CGFloat(0.65 + 0.35 * sin(time * tongue.rate + tongue.phase))
            let tall = tongue.height * flicker * heightScale(tongue.position)
            guard tall > 1 else { continue }
            let lean = CGFloat(sin(time * 4 + tongue.phase)) * base * 0.4
            cgContext.addPath(tonguePath(at: tongue.position, base: base, tall: tall, lean: lean))
            cgContext.setFillColor(palette.outer.withAlphaComponent(0.85).cgColor)
            cgContext.fillPath()
            cgContext.addPath(tonguePath(at: tongue.position, base: base / 2, tall: tall * 0.55, lean: lean * 0.6))
            cgContext.setFillColor(palette.core.withAlphaComponent(0.9).cgColor)
            cgContext.fillPath()
        }
        cgContext.setBlendMode(.normal)
    }

    private static func tonguePath(at position: CGFloat, base: CGFloat, tall: CGFloat, lean: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: position - base / 2, y: 0))
        path.addQuadCurve(to: CGPoint(x: position + lean, y: tall), control: CGPoint(x: position - base * 0.2, y: tall * 0.5))
        path.addQuadCurve(to: CGPoint(x: position + base / 2, y: 0), control: CGPoint(x: position + base * 0.2 + lean, y: tall * 0.5))
        path.closeSubpath()
        return path
    }
}
