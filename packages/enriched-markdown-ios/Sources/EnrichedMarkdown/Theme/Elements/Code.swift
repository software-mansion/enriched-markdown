import SwiftUI

public struct Code: MarkdownThemeElement {
    public var fontSpec: ThemeFontSpec?
    public var fontWeight: Font.Weight?
    public var fontDesign: Font.Design?
    public var foregroundColorSpec: ThemeColorSpec?
    public var backgroundColorSpec: ThemeColorSpec?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var textAlignment: TextAlignment?

    public init() {
        fontDesign = .monospaced
    }

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

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        applyElementStyle(to: &config.code, traitCollection: traitCollection)
        if let backgroundColorSpec {
            config.code.backgroundColor = backgroundColorSpec.resolve(traitCollection: traitCollection)
        }
    }
}
