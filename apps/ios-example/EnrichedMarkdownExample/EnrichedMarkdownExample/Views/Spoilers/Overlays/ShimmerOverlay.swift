import EnrichedMarkdown
import UIKit

/// A glossy bar in the spoiler color with a light sweep, which pops and
/// dissolves on reveal.
final class ShimmerOverlayView: SpoilerOverlayView {
    private static let sweepDuration: CFTimeInterval = 1.4

    private let sheen = CAGradientLayer()

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.color ?? .secondaryLabel
        layer.cornerRadius = style.solidBorderRadius ?? 6
        sheen.colors = [
            UIColor.white.withAlphaComponent(0),
            UIColor.white.withAlphaComponent(0.6),
            UIColor.white.withAlphaComponent(0)
        ].map(\.cgColor)
        sheen.startPoint = CGPoint(x: 0, y: 0.5)
        sheen.endPoint = CGPoint(x: 1, y: 0.5)
        sheen.locations = [-1, -0.5, 0]
        layer.addSublayer(sheen)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        sheen.frame = bounds
        guard sheen.animation(forKey: "sweep") == nil else { return }
        let sweep = CABasicAnimation(keyPath: "locations")
        sweep.fromValue = [-1, -0.5, 0]
        sweep.toValue = [1, 1.5, 2]
        sweep.duration = Self.sweepDuration
        sweep.repeatCount = .infinity
        sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        sheen.add(sweep, forKey: "sweep")
    }

    override func animateReveal(completion: @escaping () -> Void) {
        UIView.animate(
            withDuration: 0.5,
            delay: revealDelay(stagger: 0.1),
            usingSpringWithDamping: 0.55,
            initialSpringVelocity: 4,
            options: [.beginFromCurrentState]
        ) {
            self.transform = CGAffineTransform(scaleX: 1.1, y: 1.5)
            self.alpha = 0
        } completion: { _ in
            completion()
        }
    }
}

struct ShimmerOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        ShimmerOverlayView(style: style, charRange: charRange)
    }
}
