import UIKit

enum FontHelpers {
    static func ensureBold(_ font: UIFont?) -> UIFont? {
        applyTrait(to: font, bold: true, italic: false)
    }

    static func ensureItalic(_ font: UIFont?) -> UIFont? {
        applyTrait(to: font, bold: false, italic: true)
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

        let weight: UIFont.Weight = hasBoldTrait(font) ? .bold : .regular
        return UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: weight)
    }

    private static func applyTrait(to font: UIFont?, bold: Bool, italic: Bool) -> UIFont? {
        guard let font else { return nil }

        let wantsBold = bold || hasBoldTrait(font)
        let wantsItalic = italic || hasItalicTrait(font)

        if wantsBold == hasBoldTrait(font), wantsItalic == hasItalicTrait(font) {
            return font
        }

        if let variant = resolveFamilyVariant(from: font, bold: wantsBold, italic: wantsItalic) {
            return variant
        }

        if let synthesized = fontByAddingSymbolicTraits(to: font, bold: wantsBold, italic: wantsItalic) {
            return synthesized
        }

        if wantsItalic, !hasItalicTrait(font), wantsBold {
            if let italicFace = resolveFamilyVariant(from: font, bold: false, italic: true) {
                return italicFace
            }
        }

        if wantsBold, !hasBoldTrait(font), !wantsItalic,
           let boldFace = resolveFamilyVariant(from: font, bold: true, italic: false) {
            return boldFace
        }

        return font
    }

    private static func resolveFamilyVariant(from font: UIFont, bold: Bool, italic: Bool) -> UIFont? {
        let size = font.pointSize
        let faceNames = UIFont.fontNames(forFamilyName: font.familyName)
        guard !faceNames.isEmpty else { return nil }

        var bestMatch: UIFont?
        var bestScore = Int.min

        for name in faceNames {
            guard let candidate = UIFont(name: name, size: size) else { continue }
            guard matchesTraits(candidate, bold: bold, italic: italic) else { continue }

            let score = traitMatchScore(candidate, bold: bold, italic: italic)
            if score > bestScore {
                bestScore = score
                bestMatch = candidate
            }
        }

        return bestMatch
    }

    private static func matchesTraits(_ font: UIFont, bold: Bool, italic: Bool) -> Bool {
        if bold != hasBoldTrait(font) { return false }
        if italic != hasItalicTrait(font) { return false }
        return true
    }

    private static func traitMatchScore(_ font: UIFont, bold: Bool, italic: Bool) -> Int {
        var score = 0
        let traits = font.fontDescriptor.symbolicTraits
        if bold, traits.contains(.traitBold) { score += 2 }
        if italic, traits.contains(.traitItalic) { score += 2 }
        if !bold, !traits.contains(.traitBold) { score += 1 }
        if !italic, !traits.contains(.traitItalic) { score += 1 }
        return score
    }

    private static func fontByAddingSymbolicTraits(to font: UIFont, bold: Bool, italic: Bool) -> UIFont? {
        var targetTraits = font.fontDescriptor.symbolicTraits
        if bold { targetTraits.insert(.traitBold) }
        if italic { targetTraits.insert(.traitItalic) }

        guard let descriptor = font.fontDescriptor.withSymbolicTraits(targetTraits) else {
            return nil
        }

        let synthesized = UIFont(descriptor: descriptor, size: font.pointSize)

        if bold, !hasBoldTrait(synthesized) { return nil }
        if italic, !hasItalicTrait(synthesized) { return nil }

        return synthesized
    }

    static func hasBoldTrait(_ font: UIFont) -> Bool {
        if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
            return true
        }
        if let weight = fontWeight(of: font), weight >= UIFont.Weight.semibold.rawValue {
            return true
        }
        return false
    }

    static func hasItalicTrait(_ font: UIFont) -> Bool {
        if font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
            return true
        }
        if let slant = fontSlant(of: font), slant > 0 {
            return true
        }
        return false
    }

    private static func fontWeight(of font: UIFont) -> CGFloat? {
        let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        return traits?[.weight] as? CGFloat
    }

    private static func fontSlant(of font: UIFont) -> CGFloat? {
        let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        return traits?[.slant] as? CGFloat
    }
}
