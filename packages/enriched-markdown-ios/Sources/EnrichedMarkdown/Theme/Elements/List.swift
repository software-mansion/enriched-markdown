import SwiftUI

public struct List: MarkdownThemeElement {
    public var fontSpec: ThemeFontSpec?
    public var fontWeight: Font.Weight?
    public var fontDesign: Font.Design?
    public var isItalic: Bool?
    public var foregroundColorSpec: ThemeColorSpec?
    public var bulletColorSpec: ThemeColorSpec?
    public var markerColorSpec: ThemeColorSpec?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var textAlignment: TextAlignment?
    public var marginLeading: CGFloat?
    public var gapWidth: CGFloat?
    public var bulletSize: CGFloat?
    public var markerMinWidth: CGFloat?

    public init() {}

    @_disfavoredOverload
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

    @_disfavoredOverload
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

    /// Indent of each nesting level on the paragraph's leading side.
    public func marginLeading(_ value: CGFloat) -> Self {
        var copy = self
        copy.marginLeading = value
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

    public func apply(to config: inout MarkdownStyleConfiguration, traitCollection: UITraitCollection) {
        applyTextStyle(to: &config.list, traitCollection: traitCollection)
        if let bulletColorSpec {
            config.list.bulletColor = bulletColorSpec.resolve(traitCollection: traitCollection)
        }
        if let markerColorSpec {
            config.list.markerColor = markerColorSpec.resolve(traitCollection: traitCollection)
        }
        if let marginLeading { config.list.marginLeading = marginLeading }
        if let gapWidth { config.list.gapWidth = gapWidth }
        if let bulletSize { config.list.bulletSize = bulletSize }
        if let markerMinWidth { config.list.markerMinWidth = markerMinWidth }
    }
}
