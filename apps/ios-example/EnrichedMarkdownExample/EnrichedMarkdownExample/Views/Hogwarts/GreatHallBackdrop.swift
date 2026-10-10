import SwiftUI

/// The Great Hall at night: stars twinkling and candles floating on slow
/// currents, each with a flickering flame and a warm glow.
struct GreatHallBackdrop: View {
    let animates: Bool

    private struct Candle {
        /// Position as shares of the screen.
        let across: CGFloat
        let down: CGFloat
        let height: CGFloat
        let phase: Double
        let drift: Double
        /// Nearer candles are larger, brighter and move more.
        let depth: CGFloat
    }

    private struct Star {
        let across: CGFloat
        let down: CGFloat
        let size: CGFloat
        let phase: Double
    }

    /// Fixed for the life of the app, so the candles never jump when the
    /// screen re-renders. They keep to the bands above the headline and
    /// below the page, so they never float through the words.
    private static let candles: [Candle] = {
        var generator = SeededGenerator(seed: 0x9B1F)
        return (0..<16).map { index in
            // The top row hangs between the status bar and the title, and
            // clear of the Back button on the left.
            let top = !index.isMultiple(of: 3)
            let across = CGFloat(index) / 16 + CGFloat.random(in: -0.03...0.03, using: &generator)
            return Candle(
                across: top ? 0.24 + across * 0.76 : across,
                down: top
                    ? CGFloat.random(in: 0.055...0.075, using: &generator)
                    : CGFloat.random(in: 0.9...0.97, using: &generator),
                height: CGFloat.random(in: 14...34, using: &generator),
                phase: Double.random(in: 0...(2 * .pi), using: &generator),
                drift: Double.random(in: 0.25...0.5, using: &generator),
                depth: CGFloat.random(in: 0.45...1, using: &generator)
            )
        }
    }()

    private static let stars: [Star] = {
        var generator = SeededGenerator(seed: 0x51A2)
        return (0..<70).map { _ in
            Star(
                across: .random(in: 0...1, using: &generator), down: .random(in: 0...1, using: &generator),
                size: .random(in: 0.6...1.8, using: &generator), phase: .random(in: 0...(2 * .pi), using: &generator)
            )
        }
    }()

    @State private var appeared = Date()

    var body: some View {
        TimelineView(.animation(paused: !animates)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            // The candles rise into place over the first two seconds.
            let arrival = min(1, timeline.date.timeIntervalSince(appeared) / 2)
            Canvas { context, size in
                drawStars(in: &context, size: size, time: time)
                for candle in Self.candles.sorted(by: { $0.depth < $1.depth }) {
                    drawCandle(candle, in: &context, size: size, time: time, arrival: arrival)
                }
            }
        }
        .background(
            LinearGradient(
                colors: [HogwartsPalette.night, Color(red: 0.06, green: 0.04, blue: 0.1), HogwartsPalette.night],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func drawStars(in context: inout GraphicsContext, size: CGSize, time: Double) {
        for star in Self.stars {
            let twinkle = 0.35 + 0.65 * abs(sin(time * 0.9 + star.phase))
            let rect = CGRect(x: star.across * size.width, y: star.down * size.height, width: star.size, height: star.size)
            context.fill(Path(ellipseIn: rect), with: .color(HogwartsPalette.parchment.opacity(twinkle * 0.7)))
        }
    }

    /// A candle floating on a slow current: it bobs and sways with a lean
    /// into its sideways drift, rises into place on arrival, and sits at
    /// its depth in size and brightness. The flame flickers and its glow
    /// breathes.
    private func drawCandle(_ candle: Candle, in context: inout GraphicsContext, size: CGSize, time: Double, arrival: Double) {
        let scale = 0.6 + 0.4 * candle.depth
        let bob = sin(time * candle.drift + candle.phase)
        let sway = cos(time * 0.3 + candle.phase)
        let eased = 1 - pow(1 - arrival, 3)
        let settle = (1 - eased) * (candle.down < 0.5 ? -1 : 1) * 60
        let center = CGPoint(
            x: candle.across * size.width + 9 * candle.depth * CGFloat(sway),
            y: candle.down * size.height + 12 * candle.depth * CGFloat(bob) + settle
        )
        let lean = -0.06 * CGFloat(sin(time * 0.3 + candle.phase))
        let flicker = 0.75 + 0.25 * abs(sin(time * 9 + candle.phase) * sin(time * 2.7))
        let alpha = eased * (0.55 + 0.45 * candle.depth)

        var layer = context
        layer.translateBy(x: center.x, y: center.y)
        layer.rotate(by: .radians(lean))
        layer.scaleBy(x: scale, y: scale)
        layer.opacity = alpha

        let glowRadius = 34 * flicker
        layer.fill(
            Path(ellipseIn: CGRect(x: -glowRadius, y: -4 - glowRadius, width: glowRadius * 2, height: glowRadius * 2)),
            with: .radialGradient(
                Gradient(colors: [HogwartsPalette.gold.opacity(0.3 * flicker), HogwartsPalette.gold.opacity(0)]),
                center: CGPoint(x: 0, y: -4), startRadius: 0, endRadius: glowRadius
            )
        )
        let body = CGRect(x: -2.2, y: 0, width: 4.4, height: candle.height)
        layer.fill(Path(roundedRect: body, cornerRadius: 1.5), with: .color(HogwartsPalette.parchment.opacity(0.85)))
        // Wax drips.
        layer.fill(Path(ellipseIn: CGRect(x: -2.6, y: 1, width: 1.6, height: 4)), with: .color(HogwartsPalette.parchment.opacity(0.7)))
        let flameTop = CGPoint(x: 0, y: -8 * flicker)
        var flame = Path()
        flame.move(to: CGPoint(x: -2.4, y: 1))
        flame.addQuadCurve(to: flameTop, control: CGPoint(x: -2.8, y: -4 * flicker))
        flame.addQuadCurve(to: CGPoint(x: 2.4, y: 1), control: CGPoint(x: 2.8, y: -4 * flicker))
        flame.closeSubpath()
        layer.fill(flame, with: .color(Color(red: 1, green: 0.78, blue: 0.35).opacity(0.95)))
        layer.fill(
            Path(ellipseIn: CGRect(x: -1, y: -3.5 * flicker, width: 2, height: 4 * flicker)),
            with: .color(Color.white.opacity(0.9))
        )
    }
}

/// A small deterministic random source, so scenery is the same every time.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 0x9E37_79B9_7F4A_7C15 | 1
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
