import SwiftUI

public struct Blockquote: MarkdownThemeElement {
    public var fontSpec: ThemeFontSpec?
    public var fontWeight: Font.Weight?
    public var fontDesign: Font.Design?
    public var foregroundColorSpec: ThemeColorSpec?
    public var backgroundColorSpec: ThemeColorSpec?
    public var borderColorSpec: ThemeColorSpec?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var textAlignment: TextAlignment?
    public var borderWidth: CGFloat?
    public var gapWidth: CGFloat?

    public init() {}

    public func backgroundStyle(_ color: Color) -> Self {
        var copy = self
        copy.backgroundColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func backgroundStyle(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.backgroundColorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    public func background(_ color: Color) -> Self {
        backgroundStyle(color)
    }

    public func background(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        backgroundStyle(semantic)
    }

    public func borderColor(_ color: Color) -> Self {
        var copy = self
        copy.borderColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func borderColor(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.borderColorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    public func borderWidth(_ value: CGFloat) -> Self {
        var copy = self
        copy.borderWidth = value
        return copy
    }

    public func gapWidth(_ value: CGFloat) -> Self {
        var copy = self
        copy.gapWidth = value
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        if fontSpec != nil || fontWeight != nil || fontDesign != nil {
            config.blockquote.font = ThemeResolver.applyFont(
                spec: fontSpec,
                weight: fontWeight,
                design: fontDesign,
                to: config.blockquote.font,
                traitCollection: traitCollection
            )
        }
        if let foregroundColorSpec {
            config.blockquote.foregroundColor = foregroundColorSpec.resolve(traitCollection: traitCollection)
        }
        if let backgroundColorSpec {
            config.blockquote.backgroundColor = backgroundColorSpec.resolve(traitCollection: traitCollection)
        }
        if let borderColorSpec {
            config.blockquote.borderColor = borderColorSpec.resolve(traitCollection: traitCollection)
        }
        if let marginTop { config.blockquote.marginTop = marginTop }
        if let marginBottom { config.blockquote.marginBottom = marginBottom }
        if let lineHeight { config.blockquote.lineHeight = lineHeight }
        if let borderWidth { config.blockquote.borderWidth = borderWidth }
        if let gapWidth { config.blockquote.gapWidth = gapWidth }
    }
}
