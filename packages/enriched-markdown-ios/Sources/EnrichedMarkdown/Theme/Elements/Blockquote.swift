import SwiftUI

public struct Blockquote: MarkdownThemeElement, BackgroundThemeElement, BorderThemeElement {
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
    public var borderWidth: CGFloat?
    public var gapWidth: CGFloat?

    public init() {}

    public func gapWidth(_ value: CGFloat) -> Self {
        var copy = self
        copy.gapWidth = value
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfiguration, traitCollection: UITraitCollection) {
        applyTextStyle(to: &config.blockquote, traitCollection: traitCollection)
        applyBackgroundColor(to: &config.blockquote.backgroundColor, traitCollection: traitCollection)
        applyBorder(
            color: &config.blockquote.borderColor, width: &config.blockquote.borderWidth, traitCollection: traitCollection
        )
        if let gapWidth { config.blockquote.gapWidth = gapWidth }
    }
}
