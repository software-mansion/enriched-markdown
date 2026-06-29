import SwiftUI
import UIKit

public protocol MarkdownThemeElement: MarkdownThemeContent {
    var fontSpec: ThemeFontSpec? { get set }
    var fontWeight: Font.Weight? { get set }
    var fontDesign: Font.Design? { get set }
    var foregroundColorSpec: ThemeColorSpec? { get set }
    var marginTop: CGFloat? { get set }
    var marginBottom: CGFloat? { get set }
    var lineHeight: CGFloat? { get set }
    var textAlignment: TextAlignment? { get set }
}

public extension MarkdownThemeElement {
    func font(_ font: Font) -> Self {
        var copy = self
        copy.fontSpec = ThemeResolver.font(from: font, traitCollection: .current)
        return copy
    }

    func bold() -> Self {
        var copy = self
        copy.fontWeight = .bold
        return copy
    }

    func foregroundStyle(_ color: Color) -> Self {
        var copy = self
        copy.foregroundColorSpec = ThemeResolver.color(from: color, traitCollection: .current)
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

    func textAlignment(_ alignment: TextAlignment) -> Self {
        var copy = self
        copy.textAlignment = alignment
        return copy
    }

    func applyElementStyle(
        to style: inout ElementStyle,
        traitCollection: UITraitCollection
    ) {
        if fontSpec != nil || fontWeight != nil || fontDesign != nil {
            style.font = ThemeResolver.applyFont(
                spec: fontSpec,
                weight: fontWeight,
                design: fontDesign,
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
        if let textAlignment { style.textAlignment = nsTextAlignment(from: textAlignment) }
    }

    private func nsTextAlignment(from alignment: TextAlignment) -> NSTextAlignment {
        switch alignment {
        case .leading: return .left
        case .center: return .center
        case .trailing: return .right
        }
    }
}
