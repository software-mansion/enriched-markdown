import SwiftUI

public struct Table: MarkdownThemeElement {
    public var fontSpec: ThemeFontSpec?
    public var fontWeight: Font.Weight?
    public var fontDesign: Font.Design?
    public var headerFontSpec: ThemeFontSpec?
    public var foregroundColorSpec: ThemeColorSpec?
    public var headerTextColorSpec: ThemeColorSpec?
    public var headerBackgroundColorSpec: ThemeColorSpec?
    public var rowEvenBackgroundColorSpec: ThemeColorSpec?
    public var rowOddBackgroundColorSpec: ThemeColorSpec?
    public var borderColorSpec: ThemeColorSpec?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var textAlignment: TextAlignment?
    public var borderWidth: CGFloat?
    public var borderRadius: CGFloat?
    public var cellPaddingHorizontal: CGFloat?
    public var cellPaddingVertical: CGFloat?
    public var align: TableAlignment?

    public init() {}

    public func headerFontFamily(_ name: String, size: CGFloat) -> Self {
        var copy = self
        copy.headerFontSpec = .custom(name: name, size: size)
        return copy
    }

    public func headerTextColor(_ color: Color) -> Self {
        var copy = self
        copy.headerTextColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func headerTextColor(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.headerTextColorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    public func headerBackground(_ color: Color) -> Self {
        var copy = self
        copy.headerBackgroundColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func headerBackground(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.headerBackgroundColorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    public func rowEvenBackground(_ color: Color) -> Self {
        var copy = self
        copy.rowEvenBackgroundColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func rowEvenBackground(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.rowEvenBackgroundColorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    public func rowOddBackground(_ color: Color) -> Self {
        var copy = self
        copy.rowOddBackgroundColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func rowOddBackground(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.rowOddBackgroundColorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
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

    public func borderWidth(_ value: CGFloat) -> Self {
        var copy = self
        copy.borderWidth = value
        return copy
    }

    public func cornerRadius(_ value: CGFloat) -> Self {
        var copy = self
        copy.borderRadius = value
        return copy
    }

    public func borderRadius(_ value: CGFloat) -> Self {
        cornerRadius(value)
    }

    public func cellPaddingHorizontal(_ value: CGFloat) -> Self {
        var copy = self
        copy.cellPaddingHorizontal = value
        return copy
    }

    public func cellPaddingVertical(_ value: CGFloat) -> Self {
        var copy = self
        copy.cellPaddingVertical = value
        return copy
    }

    public func align(_ value: TableAlignment) -> Self {
        var copy = self
        copy.align = value
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        applyColors(to: &config, traitCollection: traitCollection)
        applyMetrics(to: &config, traitCollection: traitCollection)
    }

    private func applyColors(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        if let foregroundColorSpec {
            config.table.foregroundColor = foregroundColorSpec.resolve(traitCollection: traitCollection)
        }
        if let headerTextColorSpec {
            config.table.headerTextColor = headerTextColorSpec.resolve(traitCollection: traitCollection)
        }
        if let headerBackgroundColorSpec {
            config.table.headerBackgroundColor = headerBackgroundColorSpec.resolve(traitCollection: traitCollection)
        }
        if let rowEvenBackgroundColorSpec {
            config.table.rowEvenBackgroundColor = rowEvenBackgroundColorSpec.resolve(traitCollection: traitCollection)
        }
        if let rowOddBackgroundColorSpec {
            config.table.rowOddBackgroundColor = rowOddBackgroundColorSpec.resolve(traitCollection: traitCollection)
        }
        if let borderColorSpec {
            config.table.borderColor = borderColorSpec.resolve(traitCollection: traitCollection)
        }
    }

    private func applyMetrics(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        if fontSpec != nil || fontWeight != nil || fontDesign != nil {
            config.table.font = ThemeResolver.applyFont(
                spec: fontSpec,
                weight: fontWeight,
                design: fontDesign,
                to: config.table.font,
                traitCollection: traitCollection
            )
        }
        if headerFontSpec != nil {
            config.table.headerFont = ThemeResolver.applyFont(
                spec: headerFontSpec,
                weight: nil,
                design: nil,
                to: config.table.headerFont,
                traitCollection: traitCollection
            )
        }
        if let marginTop { config.table.marginTop = marginTop }
        if let marginBottom { config.table.marginBottom = marginBottom }
        if let lineHeight { config.table.lineHeight = lineHeight }
        if let borderWidth { config.table.borderWidth = borderWidth }
        if let borderRadius { config.table.borderRadius = borderRadius }
        if let cellPaddingHorizontal { config.table.cellPaddingHorizontal = cellPaddingHorizontal }
        if let cellPaddingVertical { config.table.cellPaddingVertical = cellPaddingVertical }
        if let align { config.table.align = align }
    }
}
