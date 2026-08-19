import SwiftUI

public struct ThematicBreak: MarkdownThemeContent {
    public var colorSpec: ThemeColorSpec?
    public var height: CGFloat?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?

    public init() {}

    public func color(_ color: Color) -> Self {
        var copy = self
        copy.colorSpec = ThemeResolver.color(from: color, traitCollection: .current)
        return copy
    }

    public func color(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.colorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    public func foregroundStyle(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        color(semantic)
    }

    public func height(_ value: CGFloat) -> Self {
        var copy = self
        copy.height = value
        return copy
    }

    public func marginTop(_ value: CGFloat) -> Self {
        var copy = self
        copy.marginTop = value
        return copy
    }

    public func marginBottom(_ value: CGFloat) -> Self {
        var copy = self
        copy.marginBottom = value
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        if let colorSpec {
            config.thematicBreak.color = colorSpec.resolve(traitCollection: traitCollection)
        }
        if let height { config.thematicBreak.height = height }
        if let marginTop { config.thematicBreak.marginTop = marginTop }
        if let marginBottom { config.thematicBreak.marginBottom = marginBottom }
    }
}
