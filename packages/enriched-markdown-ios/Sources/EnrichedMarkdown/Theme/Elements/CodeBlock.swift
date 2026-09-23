import SwiftUI

public struct CodeBlock: MarkdownThemeElement, BackgroundThemeElement, BorderThemeElement {
    public var fontSpec: ThemeFontSpec?
    public var fontWeight: Font.Weight?
    public var fontDesign: Font.Design?
    public var isItalic: Bool?
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

    public init() {}

    public var defaultFontDesign: Font.Design? { .monospaced }

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

    public func apply(to config: inout MarkdownStyleConfiguration, traitCollection: UITraitCollection) {
        applyTextStyle(to: &config.codeBlock, traitCollection: traitCollection)
        applyBackgroundColor(to: &config.codeBlock.backgroundColor, traitCollection: traitCollection)
        applyBorder(
            color: &config.codeBlock.borderColor, width: &config.codeBlock.borderWidth, traitCollection: traitCollection
        )
        if let padding { config.codeBlock.padding = padding }
        if let cornerRadius { config.codeBlock.cornerRadius = cornerRadius }
    }
}
