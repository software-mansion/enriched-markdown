import SwiftUI

public struct Highlight: MarkdownThemeElement, BackgroundThemeElement {
    public var fontSpec: ThemeFontSpec?
    public var fontWeight: Font.Weight?
    public var fontDesign: Font.Design?
    public var foregroundColorSpec: ThemeColorSpec?
    public var backgroundColorSpec: ThemeColorSpec?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var textAlignment: TextAlignment?

    public init() {}

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        applyElementStyle(to: &config.highlight, traitCollection: traitCollection)
        applyBackgroundColor(to: &config.highlight.backgroundColor, traitCollection: traitCollection)
    }
}
