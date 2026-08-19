import SwiftUI

public struct Link: MarkdownThemeElement {
    public var fontSpec: ThemeFontSpec?
    public var fontWeight: Font.Weight?
    public var fontDesign: Font.Design?
    public var foregroundColorSpec: ThemeColorSpec?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var textAlignment: TextAlignment?
    public var underline: Bool?

    public init() {}

    public func underline(_ enabled: Bool = true) -> Self {
        var copy = self
        copy.underline = enabled
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        applyElementStyle(to: &config.link, traitCollection: traitCollection)
        if let underline {
            config.link.underline = underline
        }
    }
}
