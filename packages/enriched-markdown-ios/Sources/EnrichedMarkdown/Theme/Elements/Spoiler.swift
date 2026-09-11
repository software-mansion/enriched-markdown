import SwiftUI

/// Styles the overlay that conceals `||spoiler||` text; the text itself keeps
/// the surrounding font and color. Which overlay is drawn comes from
/// `.markdownSpoilerOverlay`.
public struct Spoiler: BackgroundThemeElement {
    public var colorSpec: ThemeColorSpec?
    /// Backdrop under the particles; the solid overlay ignores it.
    public var backgroundColorSpec: ThemeColorSpec?
    public var particleDensity: CGFloat?
    public var particleSpeed: CGFloat?
    public var solidBorderRadius: CGFloat?

    public init() {}

    /// Color of the particles or of the solid box.
    public func color(_ color: Color) -> Self {
        var copy = self
        copy.colorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func color(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.colorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    public func particleDensity(_ value: CGFloat) -> Self {
        var copy = self
        copy.particleDensity = value
        return copy
    }

    public func particleSpeed(_ value: CGFloat) -> Self {
        var copy = self
        copy.particleSpeed = value
        return copy
    }

    public func solidBorderRadius(_ value: CGFloat) -> Self {
        var copy = self
        copy.solidBorderRadius = value
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        if let colorSpec {
            config.spoiler.color = colorSpec.resolve(traitCollection: traitCollection)
        }
        applyBackgroundColor(to: &config.spoiler.backgroundColor, traitCollection: traitCollection)
        if let particleDensity { config.spoiler.particleDensity = particleDensity }
        if let particleSpeed { config.spoiler.particleSpeed = particleSpeed }
        if let solidBorderRadius { config.spoiler.solidBorderRadius = solidBorderRadius }
    }
}
