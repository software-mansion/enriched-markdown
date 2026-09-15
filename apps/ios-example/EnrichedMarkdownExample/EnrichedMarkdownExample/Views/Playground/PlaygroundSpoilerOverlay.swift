import EnrichedMarkdown
import UIKit

/// `.custom` is the blur sample from the package README.
enum PlaygroundSpoilerOverlay: String {
    case particles = "Particles"
    case solid = "Solid"
    case custom = "Custom"

    var next: Self {
        switch self {
        case .particles: return .solid
        case .solid: return .custom
        case .custom: return .particles
        }
    }

    var provider: any SpoilerOverlayProvider {
        switch self {
        case .particles: return .particles
        case .solid: return .solid
        case .custom: return BlurOverlayProvider()
        }
    }
}

final class BlurOverlayView: SpoilerOverlayView {
    private static let context = CIContext()

    override func layoutSubviews() {
        super.layoutSubviews()
        let text = UIGraphicsImageRenderer(bounds: bounds).image { _ in concealedText.draw(at: .zero) }
        guard let input = CIImage(image: text) else { return }
        layer.contents = Self.context.createCGImage(input.applyingGaussianBlur(sigma: 6), from: input.extent)
    }
}

struct BlurOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        let view = BlurOverlayView(charRange: charRange)
        view.backgroundColor = style.backgroundColor ?? .systemBackground
        return view
    }
}
