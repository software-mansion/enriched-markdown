import SwiftUI

public struct CodeBlock: MarkdownThemeElement, BackgroundThemeElement {
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
    public var padding: CGFloat?
    public var cornerRadius: CGFloat?
    public var borderWidth: CGFloat?

    public init() {
        fontDesign = .monospaced
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

    public func padding(_ value: CGFloat) -> Self {
        var copy = self
        copy.padding = value
        return copy
    }

    public func cornerRadius(_ value: CGFloat) -> Self {
        var copy = self
        copy.cornerRadius = value
        return copy
    }

    public func borderWidth(_ value: CGFloat) -> Self {
        var copy = self
        copy.borderWidth = value
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        applyTextStyle(to: &config.codeBlock, traitCollection: traitCollection)
        applyBackgroundColor(to: &config.codeBlock.backgroundColor, traitCollection: traitCollection)
        if let borderColorSpec {
            config.codeBlock.borderColor = borderColorSpec.resolve(traitCollection: traitCollection)
        }
        if let padding { config.codeBlock.padding = padding }
        if let cornerRadius { config.codeBlock.cornerRadius = cornerRadius }
        if let borderWidth { config.codeBlock.borderWidth = borderWidth }
    }
}
