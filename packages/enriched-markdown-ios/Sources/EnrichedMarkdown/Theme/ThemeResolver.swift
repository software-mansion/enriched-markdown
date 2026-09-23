import CoreText
import OSLog
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
        case tertiary
        case quaternary
        case tint
    }

    package func resolve(traitCollection: UITraitCollection) -> UIColor {
        switch self {
        case let .semantic(semantic):
            switch semantic {
            case .primary:
                return UIColor.label.resolvedColor(with: traitCollection)
            case .secondary:
                return UIColor.secondaryLabel.resolvedColor(with: traitCollection)
            case .tint:
                return UIColor.tintColor.resolvedColor(with: traitCollection)
            case .tertiary:
                return UIColor.tertiaryLabel.resolvedColor(with: traitCollection)
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
        var weight: Font.Weight?
    }

    private static let logger = Logger(subsystem: "com.swmansion.EnrichedMarkdown", category: "Theme")

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

    /// Every `Font` a theme resolves without private API: the eleven text
    /// styles plain (`.body`), by design, and by design and weight
    /// (`Font.system(_:design:weight:)`), in both the iOS 13 and iOS 16
    /// spellings. Built once; `Font` is `Hashable`.
    private static let textStyleFonts: [Font: ResolvedFont] = {
        var table: [Font: ResolvedFont] = [:]
        let designs: [Font.Design?] = [nil, .default, .monospaced, .serif, .rounded]
        let weights: [Font.Weight?] = [
            nil, .ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black
        ]
        for (swiftStyle, uiStyle) in systemTextStylePairs {
            table[Font.system(swiftStyle)] = ResolvedFont(spec: .textStyle(uiStyle))
            for design in designs {
                let resolvedDesign = design == .default ? nil : design
                if let design {
                    table[Font.system(swiftStyle, design: design)] = ResolvedFont(
                        spec: .textStyle(uiStyle), design: resolvedDesign
                    )
                }
                for weight in weights {
                    table[Font.system(swiftStyle, design: design, weight: weight)] = ResolvedFont(
                        spec: .textStyle(uiStyle), design: resolvedDesign, weight: weight
                    )
                }
            }
        }
        for (font, uiStyle) in directTextStyleMappings {
            table[font] = ResolvedFont(spec: .textStyle(uiStyle))
        }
        return table
    }()

    /// Point-sized, custom, and modified fonts (`.system(size:)`, `.custom`,
    /// `.weight()`, `.italic()`) carry their values in SwiftUI's private
    /// font box, so they cannot be read back; they log and fall back to
    /// `.body`. `font(size:weight:design:)` and `font(custom:size:)` are the
    /// explicit forms for those.
    static func resolveFont(from font: Font, traitCollection: UITraitCollection) -> ResolvedFont {
        if let resolved = textStyleFonts[font] {
            return resolved
        }
        logger.warning(
            """
            EnrichedMarkdown: .font() only resolves text styles such as .body or \
            .system(.title, design: .serif, weight: .bold); falling back to .body. \
            Use .font(size:weight:design:) for a point size or .font(custom:size:) for a custom face.
            """
        )
        return ResolvedFont(spec: .textStyle(.body))
    }

    static func color(from color: Color, traitCollection: UITraitCollection) -> ThemeColorSpec {
        let uiColor = UIColor(color)
        return .uiColor(uiColor)
    }

    /// Resolves an element's font over `base`, the lower layer's font. With
    /// no spec, the weight, design, and italic apply to `base` itself, so
    /// `Heading(1).bold()` layers over the default theme. A custom face
    /// takes only a bold weight (its family's bold face) and italic; design
    /// is a system-font notion. `italic` nil leaves the slant alone, false
    /// removes one a lower layer set.
    static func applyFont(
        spec: ThemeFontSpec?,
        weight: Font.Weight?,
        design: Font.Design?,
        italic: Bool? = nil,
        to base: UIFont?,
        traitCollection: UITraitCollection
    ) -> UIFont? {
        guard var font = spec?.resolve(traitCollection: traitCollection) ?? base else { return nil }
        let isCustomFace: Bool
        if let spec {
            if case .custom = spec { isCustomFace = true } else { isCustomFace = false }
        } else {
            isCustomFace = !font.isSystemFace
        }

        if isCustomFace {
            font = applyWeightToCustomFont(font, weight: weight)
        } else {
            if let weight {
                font = font.withWeight(uiFontWeight(from: weight))
            }
            if let design {
                let uiDesign = uiFontDesign(from: design)
                if uiDesign == .monospaced {
                    let uiWeight = weight.map(uiFontWeight(from:)) ?? font.weightTrait
                    font = UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: uiWeight)
                } else if let descriptor = font.fontDescriptor.withDesign(uiDesign) {
                    font = UIFont(descriptor: descriptor, size: font.pointSize)
                }
            }
        }

        switch italic {
        case true?: font = FontHelpers.ensureItalic(font) ?? font
        case false?: font = FontHelpers.removeItalic(font) ?? font
        case nil: break
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
    /// System faces carry a leading dot in their family name (`.AppleSystemUIFont`).
    var isSystemFace: Bool {
        familyName.hasPrefix(".")
    }

    /// The weight the descriptor carries, `.regular` when it has none.
    var weightTrait: UIFont.Weight {
        let traits = fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        guard let raw = traits?[.weight] as? CGFloat else { return .regular }
        return UIFont.Weight(rawValue: raw)
    }

    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let traits: [UIFontDescriptor.TraitKey: Any] = [
            .weight: weight
        ]
        let descriptor = fontDescriptor.addingAttributes([.traits: traits])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
