import SwiftUI

public struct Link: MarkdownThemeElement, BackgroundThemeElement {
    public let pattern: String?
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
    public var underline: Bool?

    public init() {
        pattern = nil
    }

    public init(matching pattern: String) {
        self.pattern = pattern
    }

    public func underline(_ enabled: Bool = true) -> Self {
        var copy = self
        copy.underline = enabled
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfiguration, traitCollection: UITraitCollection) {
        var style = pattern.map { config.linkVariant(for: $0) ?? ElementStyle() } ?? config.link
        applyElementStyle(to: &style, traitCollection: traitCollection)
        applyBackgroundColor(to: &style.backgroundColor, traitCollection: traitCollection)
        if let underline {
            style.underline = underline
        }
        if let pattern {
            config.setLinkVariant(style, for: pattern)
        } else {
            config.link = style
        }
    }
}
