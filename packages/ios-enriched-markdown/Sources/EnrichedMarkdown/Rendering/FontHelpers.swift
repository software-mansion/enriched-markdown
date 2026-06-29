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
}
