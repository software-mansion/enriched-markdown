import SwiftUI
import UIKit

public protocol MarkdownThemeElement: MarkdownThemeContent {
    var fontSpec: ThemeFontSpec? { get set }
    var fontWeight: Font.Weight? { get set }
    var fontDesign: Font.Design? { get set }
    var isItalic: Bool? { get set }
    var foregroundColorSpec: ThemeColorSpec? { get set }
    var marginTop: CGFloat? { get set }
    var marginBottom: CGFloat? { get set }
    var lineHeight: CGFloat? { get set }
    var textAlignment: TextAlignment? { get set }
    /// The design an element's own font takes when `fontDesign` is not set;
    /// code elements answer `.monospaced`. It never touches a lower layer's
    /// font, so `CodeBlock().foregroundStyle(.red)` keeps a serif code font.
    var defaultFontDesign: Font.Design? { get }
}

public extension MarkdownThemeElement {
    /// Elements written before `italic()` existed have nowhere to keep it.
    var isItalic: Bool? {
        get { nil }
        set { _ = newValue }
    }

    var defaultFontDesign: Font.Design? { nil }

    /// A SwiftUI text style in any spelling (`.body`, `.system(.title,
    /// design: .serif, weight: .bold)`), tracking Dynamic Type. Point-sized
    /// and custom fonts take `font(size:weight:design:)` and
    /// `font(custom:size:)`; any other `Font` logs and renders as `.body`.
    func font(_ font: Font) -> Self {
        var copy = self
        let resolved = ThemeResolver.resolveFont(from: font, traitCollection: .current)
        copy.fontSpec = resolved.spec
        if let design = resolved.design {
            copy.fontDesign = design
        }
        if let weight = resolved.weight {
            copy.fontWeight = weight
        }
        return copy
    }

    /// A fixed point size, as `Font.system(size:weight:design:)`. A nil
    /// design keeps the element's current one.
    func font(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design? = nil) -> Self {
        var copy = self
        copy.fontSpec = .system(size: size, weight: .regular, design: .default)
        copy.fontWeight = weight
        if let design {
            copy.fontDesign = design
        }
        return copy
    }

    /// A custom face by PostScript name, as `Font.custom(_:size:)`. Faces
    /// bundled as `<name>.ttf` / `.otf` (optionally under `Fonts/`) are
    /// registered on first use.
    func font(custom name: String, size: CGFloat) -> Self {
        var copy = self
        copy.fontSpec = .custom(name: name, size: size)
        return copy
    }

    func fontWeight(_ weight: Font.Weight) -> Self {
        var copy = self
        copy.fontWeight = weight
        return copy
    }

    func bold() -> Self {
        fontWeight(.bold)
    }

    /// Italicizes with the family's italic face, or a synthesized slant
    /// when it has none; `italic(false)` removes an italic a lower layer set.
    func italic(_ isActive: Bool = true) -> Self {
        var copy = self
        copy.isItalic = isActive
        return copy
    }

    func fontDesign(_ design: Font.Design) -> Self {
        var copy = self
        copy.fontDesign = design
        return copy
    }

    @_disfavoredOverload
    func foregroundStyle(_ color: Color) -> Self {
        var copy = self
        copy.foregroundColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    func foregroundStyle(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.foregroundColorSpec = .semantic(semantic)
        return copy
    }

    func marginTop(_ value: CGFloat) -> Self {
        var copy = self
        copy.marginTop = value
        return copy
    }

    func marginBottom(_ value: CGFloat) -> Self {
        var copy = self
        copy.marginBottom = value
        return copy
    }

    func lineHeight(_ value: CGFloat) -> Self {
        var copy = self
        copy.lineHeight = value
        return copy
    }

    func multilineTextAlignment(_ alignment: TextAlignment) -> Self {
        var copy = self
        copy.textAlignment = alignment
        return copy
    }

    func applyElementStyle(
        to style: inout ElementStyle,
        traitCollection: UITraitCollection
    ) {
        applyTextStyle(to: &style, traitCollection: traitCollection)
    }

    /// Writes the set font, color, margins, and line height into any style record.
    package func applyTextStyle<Style: TextStyleRecord>(
        to style: inout Style,
        traitCollection: UITraitCollection
    ) {
        applyBaseTextStyle(to: &style, traitCollection: traitCollection)
    }

    /// `applyTextStyle` plus the alignment, for records that carry one.
    package func applyTextStyle<Style: AlignableTextStyleRecord>(
        to style: inout Style,
        traitCollection: UITraitCollection
    ) {
        applyBaseTextStyle(to: &style, traitCollection: traitCollection)
        if let textAlignment { style.textAlignment = NSTextAlignment(textAlignment) }
    }

    private func applyBaseTextStyle<Style: TextStyleRecord>(
        to style: inout Style,
        traitCollection: UITraitCollection
    ) {
        let design = fontDesign ?? (fontSpec != nil ? defaultFontDesign : nil)
        if fontSpec != nil || fontWeight != nil || design != nil || isItalic != nil {
            style.font = ThemeResolver.applyFont(
                spec: fontSpec,
                weight: fontWeight,
                design: design,
                italic: isItalic,
                to: style.font,
                traitCollection: traitCollection
            )
        }
        if let foregroundColorSpec {
            style.foregroundColor = foregroundColorSpec.resolve(traitCollection: traitCollection)
        }
        if let marginTop { style.marginTop = marginTop }
        if let marginBottom { style.marginBottom = marginBottom }
        if let lineHeight { style.lineHeight = lineHeight }
    }
}

package extension NSTextAlignment {
    init(_ alignment: TextAlignment) {
        switch alignment {
        case .leading: self = .left
        case .center: self = .center
        case .trailing: self = .right
        }
    }
}
