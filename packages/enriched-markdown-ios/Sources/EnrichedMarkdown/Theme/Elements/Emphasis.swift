import SwiftUI

public struct Emphasis: MarkdownThemeElement {
    public var fontSpec: ThemeFontSpec?
    public var fontWeight: Font.Weight?
    public var fontDesign: Font.Design?
    public var foregroundColorSpec: ThemeColorSpec?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var textAlignment: TextAlignment?

    public init() {}

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        applyElementStyle(to: &config.emphasis, traitCollection: traitCollection)
    }
}
