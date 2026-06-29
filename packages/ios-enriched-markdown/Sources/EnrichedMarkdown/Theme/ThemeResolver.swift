import SwiftUI
import UIKit

public enum ThemeFontSpec: Equatable, Sendable {
    case textStyle(UIFont.TextStyle)
    case system(size: CGFloat, weight: UIFont.Weight, design: UIFontDescriptor.SystemDesign)

    func resolve(traitCollection: UITraitCollection) -> UIFont {
        switch self {
        case let .textStyle(style):
            return UIFont.preferredFont(forTextStyle: style, compatibleWith: traitCollection)
        case let .system(size, weight, design):
            let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body, compatibleWith: traitCollection)
                .withDesign(design)?
                .addingAttributes([
                    .traits: [UIFontDescriptor.TraitKey.weight: weight]
                ]) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body, compatibleWith: traitCollection)
            return UIFont(descriptor: descriptor, size: size)
        }
    }
}

public enum ThemeColorSpec: Equatable, Sendable {
    case semantic(SemanticColor)
    case uiColor(UIColor)

    public enum SemanticColor: Equatable, Sendable {
        case primary
        case secondary
        case tint
        case quaternary
    }

    func resolve(traitCollection: UITraitCollection) -> UIColor {
        switch self {
        case let .semantic(semantic):
            switch semantic {
            case .primary:
                return UIColor.label.resolvedColor(with: traitCollection)
            case .secondary:
                return UIColor.secondaryLabel.resolvedColor(with: traitCollection)
            case .tint:
                return UIColor.tintColor.resolvedColor(with: traitCollection)
            case .quaternary:
                return UIColor.quaternaryLabel.resolvedColor(with: traitCollection)
            }
        case let .uiColor(color):
            return color.resolvedColor(with: traitCollection)
        }
    }
}

enum ThemeResolver {
    static func font(from font: Font, traitCollection: UITraitCollection) -> ThemeFontSpec {
        // Map common SwiftUI text styles to UIFont.TextStyle
        if font == .body { return .textStyle(.body) }
        if font == .callout { return .textStyle(.callout) }
        if font == .caption { return .textStyle(.caption1) }
        if font == .caption2 { return .textStyle(.caption2) }
        if font == .footnote { return .textStyle(.footnote) }
        if font == .headline { return .textStyle(.headline) }
        if font == .subheadline { return .textStyle(.subheadline) }
        if font == .title { return .textStyle(.title1) }
        if font == .title2 { return .textStyle(.title2) }
        if font == .title3 { return .textStyle(.title3) }
        if font == .largeTitle { return .textStyle(.largeTitle) }
        return .textStyle(.body)
    }

    static func color(from color: Color, traitCollection: UITraitCollection) -> ThemeColorSpec {
        let uiColor = UIColor(color)
        return .uiColor(uiColor)
    }

    static func applyFont(
        spec: ThemeFontSpec?,
        weight: Font.Weight?,
        design: Font.Design?,
        to base: UIFont?,
        traitCollection: UITraitCollection
    ) -> UIFont? {
        guard let spec else { return base }
        var font = spec.resolve(traitCollection: traitCollection)

        if let weight {
            let uiWeight = uiFontWeight(from: weight)
            font = font.withWeight(uiWeight)
        }

        if let design {
            let uiDesign = uiFontDesign(from: design)
            if let descriptor = font.fontDescriptor.withDesign(uiDesign) {
                font = UIFont(descriptor: descriptor, size: font.pointSize)
            }
        }

        return font
    }

    private static func uiFontWeight(from weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }

    private static func uiFontDesign(from design: Font.Design) -> UIFontDescriptor.SystemDesign {
        switch design {
        case .default: return .default
        case .serif: return .serif
        case .rounded: return .rounded
        case .monospaced: return .monospaced
        default: return .default
        }
    }
}

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let traits: [UIFontDescriptor.TraitKey: Any] = [
            .weight: weight
        ]
        let descriptor = fontDescriptor.addingAttributes([.traits: traits])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
