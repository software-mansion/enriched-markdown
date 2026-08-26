import SwiftUI

public struct Heading: MarkdownThemeElement {
    public let level: Int
    public var fontSpec: ThemeFontSpec?
    public var fontWeight: Font.Weight?
    public var fontDesign: Font.Design?
    public var foregroundColorSpec: ThemeColorSpec?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var textAlignment: TextAlignment?

    public init(_ level: Int) {
        self.level = max(1, min(level, 6))
    }

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        var style = config.headingStyle(for: level)
        applyElementStyle(to: &style, traitCollection: traitCollection)
        config.setHeadingStyle(style, for: level)
    }
}
