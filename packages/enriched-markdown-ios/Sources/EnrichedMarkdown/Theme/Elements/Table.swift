import OSLog
import SwiftUI

public struct Table: MarkdownThemeElement, BorderThemeElement {
    public var fontSpec: ThemeFontSpec?
    public var fontWeight: Font.Weight?
    public var fontDesign: Font.Design?
    public var isItalic: Bool?
    public var headerFontSpec: ThemeFontSpec?
    public var headerFontWeight: Font.Weight?
    public var headerFontDesign: Font.Design?
    public var foregroundColorSpec: ThemeColorSpec?
    public var headerForegroundColorSpec: ThemeColorSpec?
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

    /// The header row's font, a SwiftUI text style as `font(_:)` takes.
    public func headerFont(_ font: Font) -> Self {
        var copy = self
        let resolved = ThemeResolver.resolveFont(from: font, traitCollection: .current)
        copy.headerFontSpec = resolved.spec
        if let design = resolved.design { copy.headerFontDesign = design }
        if let weight = resolved.weight { copy.headerFontWeight = weight }
        return copy
    }

    /// The header row in a custom face, as `font(custom:size:)`.
    public func headerFont(custom name: String, size: CGFloat) -> Self {
        var copy = self
        copy.headerFontSpec = .custom(name: name, size: size)
        return copy
    }

    @_disfavoredOverload
    public func headerForegroundStyle(_ color: Color) -> Self {
        var copy = self
        copy.headerForegroundColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func headerForegroundStyle(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.headerForegroundColorSpec = ThemeColorModifiers.spec(from: semantic)
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

    @_disfavoredOverload
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

    @_disfavoredOverload
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

    public func cornerRadius(_ value: CGFloat) -> Self {
        var copy = self
        copy.cornerRadius = value
        return copy
    }

    /// Inset of every cell; a nil side keeps what a lower theme layer set.
    public func cellPadding(horizontal: CGFloat? = nil, vertical: CGFloat? = nil) -> Self {
        var copy = self
        if let horizontal { copy.cellPaddingHorizontal = horizontal }
        if let vertical { copy.cellPaddingVertical = vertical }
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
    public func apply(to config: inout MarkdownStyleConfiguration, traitCollection: UITraitCollection) {
        applyColors(to: &config, traitCollection: traitCollection)
        applyMetrics(to: &config, traitCollection: traitCollection)
    }

    private func applyColors(to config: inout MarkdownStyleConfiguration, traitCollection: UITraitCollection) {
        if let headerForegroundColorSpec {
            config.table.headerTextColor = headerForegroundColorSpec.resolve(traitCollection: traitCollection)
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
        applyBorder(color: &config.table.borderColor, width: &config.table.borderWidth, traitCollection: traitCollection)
    }

    private func applyMetrics(to config: inout MarkdownStyleConfiguration, traitCollection: UITraitCollection) {
        applyTextStyle(to: &config.table, traitCollection: traitCollection)
        if headerFontSpec != nil || headerFontWeight != nil || headerFontDesign != nil {
            config.table.headerFont = ThemeResolver.applyFont(
                spec: headerFontSpec,
                weight: headerFontWeight,
                design: headerFontDesign,
                to: config.table.headerFont,
                traitCollection: traitCollection
            )
        }
        if let cornerRadius { config.table.cornerRadius = cornerRadius }
        if let cellPaddingHorizontal { config.table.cellPaddingHorizontal = cellPaddingHorizontal }
        if let cellPaddingVertical { config.table.cellPaddingVertical = cellPaddingVertical }
        if let alignment { config.table.alignment = alignment }
    }
}
