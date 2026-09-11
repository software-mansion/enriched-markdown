import SwiftUI

/// Colors for one GitHub alert type (`> [!NOTE]`, …). Geometry, font, and
/// spacing come from `Blockquote()`; an admonition only recolors it.
public struct Admonition: BackgroundThemeElement {
    public let type: AdmonitionType
    public var foregroundColorSpec: ThemeColorSpec?
    public var backgroundColorSpec: ThemeColorSpec?

    public init(_ type: AdmonitionType) {
        self.type = type
    }

    public func foregroundStyle(_ color: Color) -> Self {
        var copy = self
        copy.foregroundColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func foregroundStyle(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.foregroundColorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        var style = config.blockquote.admonitions[type] ?? AdmonitionStyle()
        if let foregroundColorSpec {
            style.color = foregroundColorSpec.resolve(traitCollection: traitCollection)
        }
        applyBackgroundColor(to: &style.backgroundColor, traitCollection: traitCollection)
        config.blockquote.admonitions[type] = style
    }
}
