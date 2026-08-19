import SwiftUI

public struct List: MarkdownThemeElement {
    public var fontSpec: ThemeFontSpec?
    public var fontWeight: Font.Weight?
    public var fontDesign: Font.Design?
    public var foregroundColorSpec: ThemeColorSpec?
    public var bulletColorSpec: ThemeColorSpec?
    public var markerColorSpec: ThemeColorSpec?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var textAlignment: TextAlignment?
    public var marginLeft: CGFloat?
    public var gapWidth: CGFloat?
    public var bulletSize: CGFloat?
    public var markerMinWidth: CGFloat?

    public init() {}

    public func bulletColor(_ color: Color) -> Self {
        var copy = self
        copy.bulletColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func bulletColor(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.bulletColorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    public func markerColor(_ color: Color) -> Self {
        var copy = self
        copy.markerColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func markerColor(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.markerColorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    public func marginLeft(_ value: CGFloat) -> Self {
        var copy = self
        copy.marginLeft = value
        return copy
    }

    public func gapWidth(_ value: CGFloat) -> Self {
        var copy = self
        copy.gapWidth = value
        return copy
    }

    public func bulletSize(_ value: CGFloat) -> Self {
        var copy = self
        copy.bulletSize = value
        return copy
    }

    public func markerMinWidth(_ value: CGFloat) -> Self {
        var copy = self
        copy.markerMinWidth = value
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        applyElementStyle(to: &config.list, traitCollection: traitCollection)
        if let bulletColorSpec {
            config.list.bulletColor = bulletColorSpec.resolve(traitCollection: traitCollection)
        }
        if let markerColorSpec {
            config.list.markerColor = markerColorSpec.resolve(traitCollection: traitCollection)
        }
        if let marginLeft { config.list.marginLeft = marginLeft }
        if let gapWidth { config.list.gapWidth = gapWidth }
        if let bulletSize { config.list.bulletSize = bulletSize }
        if let markerMinWidth { config.list.markerMinWidth = markerMinWidth }
    }

    private func applyElementStyle(to style: inout ListStyle, traitCollection: UITraitCollection) {
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
    }
}
