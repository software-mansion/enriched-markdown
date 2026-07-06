import SwiftUI

public struct CodeBlock: MarkdownThemeContent {
    public var fontSpec: ThemeFontSpec?
    public var fontWeight: Font.Weight?
    public var fontDesign: Font.Design?
    public var foregroundColorSpec: ThemeColorSpec?
    public var backgroundColorSpec: ThemeColorSpec?
    public var borderColorSpec: ThemeColorSpec?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var padding: CGFloat?
    public var borderRadius: CGFloat?
    public var borderWidth: CGFloat?

    public init() {
        fontDesign = .monospaced
    }

    public func font(_ font: Font) -> Self {
        var copy = self
        let resolved = ThemeResolver.resolveFont(from: font, traitCollection: .current)
        copy.fontSpec = resolved.spec
        if let design = resolved.design {
            copy.fontDesign = design
        }
        return copy
    }

    public func fontFamily(_ name: String, size: CGFloat) -> Self {
        var copy = self
        copy.fontSpec = .custom(name: name, size: size)
        return copy
    }

    public func fontSize(_ size: CGFloat, weight: Font.Weight = .regular) -> Self {
        var copy = self
        copy.fontSpec = .system(size: size, weight: .regular, design: .monospaced)
        copy.fontWeight = weight
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

    public func borderColor(_ color: Color) -> Self {
        var copy = self
        copy.borderColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func borderColor(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.borderColorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    public func padding(_ value: CGFloat) -> Self {
        var copy = self
        copy.padding = value
        return copy
    }

    public func borderRadius(_ value: CGFloat) -> Self {
        var copy = self
        copy.borderRadius = value
        return copy
    }

    public func cornerRadius(_ value: CGFloat) -> Self {
        borderRadius(value)
    }

    public func borderWidth(_ value: CGFloat) -> Self {
        var copy = self
        copy.borderWidth = value
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

    public func lineHeight(_ value: CGFloat) -> Self {
        var copy = self
        copy.lineHeight = value
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        if fontSpec != nil || fontWeight != nil || fontDesign != nil {
            config.codeBlock.font = ThemeResolver.applyFont(
                spec: fontSpec,
                weight: fontWeight,
                design: fontDesign,
                to: config.codeBlock.font,
                traitCollection: traitCollection
            )
        }
        if let foregroundColorSpec {
            config.codeBlock.foregroundColor = foregroundColorSpec.resolve(traitCollection: traitCollection)
        }
        if let backgroundColorSpec {
            config.codeBlock.backgroundColor = backgroundColorSpec.resolve(traitCollection: traitCollection)
        }
        if let borderColorSpec {
            config.codeBlock.borderColor = borderColorSpec.resolve(traitCollection: traitCollection)
        }
        if let marginTop { config.codeBlock.marginTop = marginTop }
        if let marginBottom { config.codeBlock.marginBottom = marginBottom }
        if let lineHeight { config.codeBlock.lineHeight = lineHeight }
        if let padding { config.codeBlock.padding = padding }
        if let borderRadius { config.codeBlock.borderRadius = borderRadius }
        if let borderWidth { config.codeBlock.borderWidth = borderWidth }
    }
}
