import SwiftUI
import UIKit

extension MarkdownStyleConfig {
    static func resolve(
        layers: [MarkdownTheme],
        colorScheme: ColorScheme,
        dynamicTypeSize: DynamicTypeSize
    ) -> MarkdownStyleConfig {
        let traitCollection = ThemeResolver.traitCollection(
            colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize
        )
        return resolve(layers: layers, traitCollection: traitCollection)
    }

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
