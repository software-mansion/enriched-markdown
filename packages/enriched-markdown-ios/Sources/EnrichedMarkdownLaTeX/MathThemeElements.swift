import EnrichedMarkdown
import SwiftUI

/// Root-level `$$…$$` blocks: a full-width panel with the formula aligned
/// inside it. Unset font size and color follow the paragraph.
public struct MathBlock: MarkdownThemeContent {
    public var fontSize: CGFloat?
    public var foregroundColorSpec: ThemeColorSpec?
    public var backgroundColorSpec: ThemeColorSpec?
    public var padding: CGFloat?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var textAlignment: TextAlignment?

    public init() {}

    /// Point size of the typeset formula; the face is always KaTeX's.
    public func fontSize(_ size: CGFloat) -> Self {
        var copy = self
        copy.fontSize = size
        return copy
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

    public func backgroundStyle(_ color: Color) -> Self {
        var copy = self
        copy.backgroundColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func backgroundStyle(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.backgroundColorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    public func background(_ color: Color) -> Self {
        backgroundStyle(color)
    }

    public func background(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        backgroundStyle(semantic)
    }

    /// Inset between the panel edge and the formula, on every side.
    public func padding(_ value: CGFloat) -> Self {
        var copy = self
        copy.padding = value
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

    /// Where the formula sits inside the panel when narrower than it.
    public func textAlignment(_ alignment: TextAlignment) -> Self {
        var copy = self
        copy.textAlignment = alignment
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        var style = config.mathBlock
        if let fontSize { style.fontSize = fontSize }
        if let foregroundColorSpec {
            style.foregroundColor = foregroundColorSpec.resolve(traitCollection: traitCollection)
        }
        if let backgroundColorSpec {
            style.backgroundColor = backgroundColorSpec.resolve(traitCollection: traitCollection)
        }
        if let padding { style.padding = padding }
        if let marginTop { style.marginTop = marginTop }
        if let marginBottom { style.marginBottom = marginBottom }
        if let textAlignment { style.textAlignment = NSTextAlignment(textAlignment) }
        config.mathBlock = style
    }
}

/// `$…$` in running text, and `$$…$$` inside a paragraph: typeset at the
/// surrounding font size, in this color or the surrounding text's.
public struct InlineMath: MarkdownThemeContent {
    public var foregroundColorSpec: ThemeColorSpec?

    public init() {}

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
        guard let foregroundColorSpec else { return }
        var style = config.inlineMath
        style.foregroundColor = foregroundColorSpec.resolve(traitCollection: traitCollection)
        config.inlineMath = style
    }
}

public extension MarkdownTheme {
    /// Math defaults matching the React Native package: 20pt display math
    /// centered on a padded panel. `.markdownLaTeX()` layers it right above
    /// `MarkdownTheme.default`; include it yourself when resolving a config
    /// for `MarkdownRenderer.renderLaTeX`.
    static let latexDefault = MarkdownTheme {
        MathBlock()
            .fontSize(20)
            .background(ThemeColorSpec.SemanticColor.quaternary)
            .padding(12)
            .marginBottom(16)
            .textAlignment(.center)
    }
}
