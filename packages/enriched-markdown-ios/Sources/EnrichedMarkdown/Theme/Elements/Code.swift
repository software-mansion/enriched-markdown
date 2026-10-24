import SwiftUI

public struct Code: MarkdownThemeElement, BackgroundThemeElement {
    public var fontSpec: ThemeFontSpec?
    public var fontWeight: Font.Weight?
    public var fontDesign: Font.Design?
    public var isItalic: Bool?
    public var foregroundColorSpec: ThemeColorSpec?
    public var backgroundColorSpec: ThemeColorSpec?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var textAlignment: TextAlignment?

    public init() {}

    public var defaultFontDesign: Font.Design? { .monospaced }

    public func apply(to config: inout MarkdownStyleConfiguration, traitCollection: UITraitCollection) {
        applyElementStyle(to: &config.code, traitCollection: traitCollection)
        applyBackgroundColor(to: &config.code.backgroundColor, traitCollection: traitCollection)
    }
}
