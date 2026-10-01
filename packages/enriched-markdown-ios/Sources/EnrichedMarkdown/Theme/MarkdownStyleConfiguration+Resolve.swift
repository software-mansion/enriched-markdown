import UIKit

extension MarkdownStyleConfiguration {
    public static func resolve(
        layers: [MarkdownTheme],
        traitCollection: UITraitCollection
    ) -> MarkdownStyleConfiguration {
        var config = MarkdownStyleConfiguration()
        for layer in layers {
            layer.apply(to: &config, traitCollection: traitCollection)
        }
        return config
    }

    public static func baseline(traitCollection: UITraitCollection = .current) -> MarkdownStyleConfiguration {
        resolve(layers: [.default], traitCollection: traitCollection)
    }
}
