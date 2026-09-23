import OSLog
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
    public var cornerRadius: CGFloat?
    public var cellPaddingHorizontal: CGFloat?
    public var cellPaddingVertical: CGFloat?
    public var alignment: TableAlignment?

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
        copy.cornerRadius = value
        return copy
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

    /// Horizontal placement of a table narrower than the text. Only
    /// `.leading`, `.center`, and `.trailing` apply; any other alignment
    /// logs and leaves the inherited value.
    public func alignment(_ value: HorizontalAlignment) -> Self {
        guard let tableAlignment = TableAlignment(value) else {
            Self.logger.warning("EnrichedMarkdown: Table().alignment only takes .leading, .center, or .trailing.")
            return self
        }
        var copy = self
        copy.alignment = tableAlignment
        return copy
    }

    private static let logger = Logger(subsystem: "com.swmansion.EnrichedMarkdown", category: "Theme")

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        applyColors(to: &config, traitCollection: traitCollection)
        applyMetrics(to: &config, traitCollection: traitCollection)
    }

    private func applyColors(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
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
        applyTextStyle(to: &config.table, traitCollection: traitCollection)
        if headerFontSpec != nil {
            config.table.headerFont = ThemeResolver.applyFont(
                spec: headerFontSpec,
                weight: nil,
                design: nil,
                to: config.table.headerFont,
                traitCollection: traitCollection
            )
        }
        if let borderWidth { config.table.borderWidth = borderWidth }
        if let cornerRadius { config.table.cornerRadius = cornerRadius }
        if let cellPaddingHorizontal { config.table.cellPaddingHorizontal = cellPaddingHorizontal }
        if let cellPaddingVertical { config.table.cellPaddingVertical = cellPaddingVertical }
        if let alignment { config.table.alignment = alignment }
    }
}
