import UIKit

extension MarkdownStyleConfig {
    public static func resolve(
        layers: [MarkdownTheme],
        traitCollection: UITraitCollection
    ) -> MarkdownStyleConfig {
        var config = MarkdownStyleConfig()
        for layer in layers {
            layer.apply(to: &config, traitCollection: traitCollection)
        }
        return config
    }

    public static func baseline(traitCollection: UITraitCollection = .current) -> MarkdownStyleConfig {
        resolve(layers: [.default], traitCollection: traitCollection)
    }
}
