import UIKit

enum FontHelpers {
    static func ensureBold(_ font: UIFont?) -> UIFont? {
        guard let font else { return nil }
        let traits = font.fontDescriptor.symbolicTraits
        guard !traits.contains(.traitBold) else { return font }

        guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits.union(.traitBold)) else {
            return font
        }
        return UIFont(descriptor: descriptor, size: 0)
    }

    static func ensureItalic(_ font: UIFont?) -> UIFont? {
        guard let font else { return nil }
        let traits = font.fontDescriptor.symbolicTraits
        guard !traits.contains(.traitItalic) else { return font }

        guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits.union(.traitItalic)) else {
            return font
        }
        return UIFont(descriptor: descriptor, size: 0)
    }

    static func cachedFont(from blockStyle: BlockStyle?) -> UIFont? {
        blockStyle?.font
    }

    static func ensureMonospaced(_ font: UIFont?, configFont: UIFont?) -> UIFont? {
        if let configFont {
            return configFont
        }
        guard let font else {
            return UIFont.monospacedSystemFont(
                ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
                weight: .regular
            )
        }

        let weight: UIFont.Weight = font.fontDescriptor.symbolicTraits.contains(.traitBold) ? .bold : .regular
        return UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: weight)
    }
}
