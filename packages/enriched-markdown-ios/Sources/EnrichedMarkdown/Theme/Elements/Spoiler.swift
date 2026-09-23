import SwiftUI

/// Styles the overlay that conceals `||spoiler||` text; the text itself keeps
/// the surrounding font and color. Which overlay is drawn comes from
/// `.markdownSpoilerOverlay`.
public struct Spoiler: BackgroundThemeElement {
    public var colorSpec: ThemeColorSpec?
    /// Backdrop under the particles; the solid overlay ignores it.
    public var backgroundColorSpec: ThemeColorSpec?
    /// Written only by the deprecated tuning modifiers; new code tunes the
    /// overlay itself: `.markdownSpoilerOverlay(.particles(density:speed:))`.
    public var particleDensity: CGFloat?
    public var particleSpeed: CGFloat?
    public var solidCornerRadius: CGFloat?

    public init() {}

    /// Color of the particles or of the solid box.
    @_disfavoredOverload
    public func foregroundStyle(_ color: Color) -> Self {
        var copy = self
        copy.colorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func foregroundStyle(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.colorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfiguration, traitCollection: UITraitCollection) {
        if let colorSpec {
            config.spoiler.color = colorSpec.resolve(traitCollection: traitCollection)
        }
        applyBackgroundColor(to: &config.spoiler.backgroundColor, traitCollection: traitCollection)
        if let particleDensity { config.spoiler.particleDensity = particleDensity }
        if let particleSpeed { config.spoiler.particleSpeed = particleSpeed }
        if let solidCornerRadius { config.spoiler.solidCornerRadius = solidCornerRadius }
    }
}
