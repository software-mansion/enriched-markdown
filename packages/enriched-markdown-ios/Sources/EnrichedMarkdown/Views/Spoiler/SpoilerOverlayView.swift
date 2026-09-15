import UIKit

/// One line segment of a concealed spoiler, layered over the transparent
/// text. Subclasses draw the particles or the solid box; the base handles
/// the reveal fade and reports which characters it covers.
class SpoilerOverlayView: UIView {
    static let revealDuration: TimeInterval = 0.45

    let charRange: NSRange
    private(set) var isRevealing = false

    init(charRange: NSRange) {
        self.charRange = charRange
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Hook for subclasses to speed up or stop their effect as the fade starts.
    func prepareRevealAnimation() {}

    func animateReveal(completion: @escaping () -> Void) {
        guard !isRevealing else { return }
        isRevealing = true
        prepareRevealAnimation()

        UIView.animate(
            withDuration: Self.revealDuration,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState]
        ) {
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
            completion()
        }
    }
}

final class SolidSpoilerOverlayView: SpoilerOverlayView {
    static let defaultBorderRadius: CGFloat = 4

    init(style: SpoilerStyle, charRange: NSRange) {
        super.init(charRange: charRange)
        backgroundColor = style.color ?? .secondaryLabel
        layer.cornerRadius = style.solidBorderRadius ?? Self.defaultBorderRadius
    }
}

/// Animated dot field over an opaque backdrop. The backdrop matters even
/// though the text is transparent: color glyphs (emoji) and inline images
/// ignore the foreground color and would otherwise show through.
final class ParticleSpoilerOverlayView: SpoilerOverlayView {
    static let defaultDensity: CGFloat = 8
    static let defaultSpeed: CGFloat = 20

    private struct Cell {
        let name: String
        let birthRateMin: CGFloat
        let birthRatePerArea: CGFloat
        let lifetime: Float
        let velocity: CGFloat
        let scale: CGFloat
        let alphaSpeed: Float
    }

    private enum Constants {
        static let dotImageSize: CGFloat = 6
        static let revealVelocityMultiplier: CGFloat = 10
        static let revealAlphaSpeedMultiplier: Float = 6

        // Two dot populations, tuned to match the React Native renderer.
        static let cells = [
            Cell(name: "dot1", birthRateMin: 3, birthRatePerArea: 0.013, lifetime: 1.6,
                 velocity: 8, scale: 0.25, alphaSpeed: -0.25),
            Cell(name: "dot2", birthRateMin: 1.5, birthRatePerArea: 0.007, lifetime: 1.2,
                 velocity: 12, scale: 0.18, alphaSpeed: -0.3)
        ]
    }

    private static let dotImage: CGImage? = {
        let size = Constants.dotImageSize
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
        }.cgImage
    }()

    private let style: SpoilerStyle
    private var emitterLayer: CAEmitterLayer?

    init(style: SpoilerStyle, charRange: NSRange) {
        self.style = style
        super.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let emitterLayer else {
            setupEmitter()
            return
        }
        guard !isRevealing else { return }
        emitterLayer.frame = bounds
        emitterLayer.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        emitterLayer.emitterSize = bounds.size
    }

    override func prepareRevealAnimation() {
        guard let emitterLayer else { return }
        emitterLayer.birthRate = 0
        for cell in emitterLayer.emitterCells ?? [] {
            guard let name = cell.name else { continue }
            emitterLayer.setValue(
                cell.velocity * Constants.revealVelocityMultiplier,
                forKeyPath: "emitterCells.\(name).velocity"
            )
            emitterLayer.setValue(
                cell.alphaSpeed * Constants.revealAlphaSpeedMultiplier,
                forKeyPath: "emitterCells.\(name).alphaSpeed"
            )
        }
    }

    private func makeCell(_ spec: Cell, area: CGFloat) -> CAEmitterCell {
        let density = style.particleDensity ?? Self.defaultDensity
        let speed = style.particleSpeed ?? Self.defaultSpeed

        let cell = CAEmitterCell()
        cell.name = spec.name
        cell.contents = Self.dotImage
        cell.color = (style.color ?? .secondaryLabel).cgColor
        cell.birthRate = Float(max(spec.birthRateMin, area * spec.birthRatePerArea * density / Self.defaultDensity))
        cell.lifetime = spec.lifetime
        cell.lifetimeRange = spec.lifetime * 0.3
        cell.velocity = spec.velocity * speed / Self.defaultSpeed
        cell.velocityRange = cell.velocity * 0.5
        cell.emissionRange = .pi * 2
        cell.scale = spec.scale
        cell.scaleRange = spec.scale * 0.3
        cell.alphaRange = 0.2
        cell.alphaSpeed = spec.alphaSpeed
        return cell
    }

    private func setupEmitter() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        let emitter = CAEmitterLayer()
        emitter.emitterShape = .rectangle
        emitter.renderMode = .oldestLast
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        emitter.emitterSize = bounds.size
        let area = bounds.width * bounds.height
        emitter.emitterCells = Constants.cells.map { makeCell($0, area: area) }
        // Backdate so the field starts populated instead of fading in.
        let maxLifetime = Constants.cells.map(\.lifetime).max() ?? 0
        emitter.beginTime = CACurrentMediaTime() - CFTimeInterval(maxLifetime)

        layer.addSublayer(emitter)
        emitterLayer = emitter
    }
}
