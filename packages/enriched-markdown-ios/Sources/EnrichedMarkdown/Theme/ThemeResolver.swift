import CoreText
import SwiftUI
import UIKit

public enum ThemeFontSpec: Equatable, Sendable {
    case textStyle(UIFont.TextStyle)
    case system(size: CGFloat, weight: UIFont.Weight, design: UIFontDescriptor.SystemDesign)
    case custom(name: String, size: CGFloat)

    func resolve(traitCollection: UITraitCollection) -> UIFont {
        switch self {
        case let .custom(name, size):
            if let font = ThemeResolver.loadCustomFont(named: name, size: size) {
                return font
            }
            return UIFont.systemFont(ofSize: size, weight: ThemeResolver.inferredWeight(from: name))
        case let .textStyle(style):
            return UIFont.preferredFont(forTextStyle: style, compatibleWith: traitCollection)
        case let .system(size, weight, design):
            switch design {
            case .default:
                return UIFont.systemFont(ofSize: size, weight: weight)
            case .monospaced:
                return UIFont.monospacedSystemFont(ofSize: size, weight: weight)
            case .serif, .rounded:
                let base = UIFont.systemFont(ofSize: size, weight: weight)
                guard let descriptor = base.fontDescriptor.withDesign(design) else {
                    return base
                }
                return UIFont(descriptor: descriptor, size: size)
            default:
                return UIFont.systemFont(ofSize: size, weight: weight)
            }
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
    struct ResolvedFont {
        var spec: ThemeFontSpec?
        var design: Font.Design?
    }

    private static let contentSizeCategories: [DynamicTypeSize: UIContentSizeCategory] = [
        .xSmall: .extraSmall,
        .small: .small,
        .medium: .medium,
        .large: .large,
        .xLarge: .extraLarge,
        .xxLarge: .extraExtraLarge,
        .xxxLarge: .extraExtraExtraLarge,
        .accessibility1: .accessibilityMedium,
        .accessibility2: .accessibilityLarge,
        .accessibility3: .accessibilityExtraLarge,
        .accessibility4: .accessibilityExtraExtraLarge,
        .accessibility5: .accessibilityExtraExtraExtraLarge
    ]

    private static let directTextStyleMappings: [(Font, UIFont.TextStyle)] = [
        (.body, .body),
        (.callout, .callout),
        (.caption, .caption1),
        (.caption2, .caption2),
        (.footnote, .footnote),
        (.headline, .headline),
        (.subheadline, .subheadline),
        (.title, .title1),
        (.title2, .title2),
        (.title3, .title3),
        (.largeTitle, .largeTitle)
    ]

    private static let systemTextStylePairs: [(Font.TextStyle, UIFont.TextStyle)] = [
        (.largeTitle, .largeTitle),
        (.title, .title1),
        (.title2, .title2),
        (.title3, .title3),
        (.headline, .headline),
        (.subheadline, .subheadline),
        (.body, .body),
        (.callout, .callout),
        (.footnote, .footnote),
        (.caption, .caption1),
        (.caption2, .caption2)
    ]

    static func traitCollection(
        colorScheme: ColorScheme,
        dynamicTypeSize: DynamicTypeSize
    ) -> UITraitCollection {
        let interfaceStyle: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let overrides = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: interfaceStyle),
            UITraitCollection(preferredContentSizeCategory: uiContentSizeCategory(from: dynamicTypeSize))
        ])
        return UITraitCollection(traitsFrom: [UITraitCollection.current, overrides])
    }

    private static func uiContentSizeCategory(from size: DynamicTypeSize) -> UIContentSizeCategory {
        contentSizeCategories[size] ?? .large
    }

    private static var registeredBundleFontNames = Set<String>()

    static func loadCustomFont(named name: String, size: CGFloat) -> UIFont? {
        if let font = UIFont(name: name, size: size) {
            return font
        }
        registerBundledFontIfNeeded(named: name)
        return UIFont(name: name, size: size)
    }

    private static func registerBundledFontIfNeeded(named name: String) {
        guard !registeredBundleFontNames.contains(name) else { return }
        registeredBundleFontNames.insert(name)

        let url =
            Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
            ?? Bundle.main.url(forResource: name, withExtension: "ttf")
            ?? Bundle.main.url(forResource: name, withExtension: "otf", subdirectory: "Fonts")
            ?? Bundle.main.url(forResource: name, withExtension: "otf")
        guard let url else { return }

        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    static func inferredWeight(from fontName: String) -> UIFont.Weight {
        let lower = fontName.lowercased()
        if lower.contains("semibold") { return .semibold }
        if lower.contains("bold") { return .bold }
        if lower.contains("medium") { return .medium }
        if lower.contains("light") { return .light }
        if lower.contains("thin") { return .thin }
        if lower.contains("black") { return .black }
        if lower.contains("heavy") { return .heavy }
        return .regular
    }

    static func font(from font: Font, traitCollection: UITraitCollection) -> ThemeFontSpec {
        resolveFont(from: font, traitCollection: traitCollection).spec ?? .textStyle(.body)
    }

    static func resolveFont(from font: Font, traitCollection: UITraitCollection) -> ResolvedFont {
        if let resolved = resolveSystemFont(from: font) {
            return resolved
        }
        if let resolved = resolveDirectTextStyle(from: font) {
            return resolved
        }
        return ResolvedFont(spec: .textStyle(.body), design: nil)
    }

    private static func resolveSystemFont(from font: Font) -> ResolvedFont? {
        for design in [Font.Design.default, .monospaced, .serif, .rounded] {
            for (swiftStyle, uiStyle) in systemTextStylePairs where font == Font.system(swiftStyle, design: design) {
                return ResolvedFont(
                    spec: .textStyle(uiStyle),
                    design: design == .default ? nil : design
                )
            }
        }
        return nil
    }

    private static func resolveDirectTextStyle(from font: Font) -> ResolvedFont? {
        for (swiftFont, uiStyle) in directTextStyleMappings where font == swiftFont {
            return ResolvedFont(spec: .textStyle(uiStyle), design: nil)
        }
        return nil
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
        if case .custom = spec {
            return applyWeightToCustomFont(
                spec.resolve(traitCollection: traitCollection),
                weight: weight
            )
        }

        var font = spec.resolve(traitCollection: traitCollection)

        if let weight {
            let uiWeight = uiFontWeight(from: weight)
            font = font.withWeight(uiWeight)
        }

        if let design {
            let uiDesign = uiFontDesign(from: design)
            if uiDesign == .monospaced {
                let uiWeight = weight.map(uiFontWeight(from:)) ?? .regular
                font = UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: uiWeight)
            } else if let descriptor = font.fontDescriptor.withDesign(uiDesign) {
                font = UIFont(descriptor: descriptor, size: font.pointSize)
            }
        }

        return font
    }

    private static func applyWeightToCustomFont(_ font: UIFont, weight: Font.Weight?) -> UIFont {
        guard let weight else { return font }
        let uiWeight = uiFontWeight(from: weight)
        guard uiWeight >= .semibold else { return font }
        return FontHelpers.ensureBold(font) ?? font
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
