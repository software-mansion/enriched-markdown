import UIKit

public enum TableAlignment: String, Equatable, Sendable {
    case leading
    case center
    case trailing
}

public struct TableStyle: Equatable, Sendable {
    public var font: UIFont?
    public var foregroundColor: UIColor?
    public var lineHeight: CGFloat?
    public var headerFont: UIFont?
    public var headerTextColor: UIColor?
    public var headerBackgroundColor: UIColor?
    public var rowEvenBackgroundColor: UIColor?
    public var rowOddBackgroundColor: UIColor?
    public var borderColor: UIColor?
    public var borderWidth: CGFloat?
    public var borderRadius: CGFloat?
    public var cellPaddingHorizontal: CGFloat?
    public var cellPaddingVertical: CGFloat?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var align: TableAlignment?

    public init(
        font: UIFont? = nil,
        foregroundColor: UIColor? = nil,
        lineHeight: CGFloat? = nil,
        headerFont: UIFont? = nil,
        headerTextColor: UIColor? = nil,
        headerBackgroundColor: UIColor? = nil,
        rowEvenBackgroundColor: UIColor? = nil,
        rowOddBackgroundColor: UIColor? = nil,
        borderColor: UIColor? = nil,
        borderWidth: CGFloat? = nil,
        borderRadius: CGFloat? = nil,
        cellPaddingHorizontal: CGFloat? = nil,
        cellPaddingVertical: CGFloat? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil,
        align: TableAlignment? = nil
    ) {
        self.font = font
        self.foregroundColor = foregroundColor
        self.lineHeight = lineHeight
        self.headerFont = headerFont
        self.headerTextColor = headerTextColor
        self.headerBackgroundColor = headerBackgroundColor
        self.rowEvenBackgroundColor = rowEvenBackgroundColor
        self.rowOddBackgroundColor = rowOddBackgroundColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.borderRadius = borderRadius
        self.cellPaddingHorizontal = cellPaddingHorizontal
        self.cellPaddingVertical = cellPaddingVertical
        self.marginTop = marginTop
        self.marginBottom = marginBottom
        self.align = align
    }

    public mutating func merge(_ other: TableStyle) {
        font = other.font ?? font
        foregroundColor = other.foregroundColor ?? foregroundColor
        lineHeight = other.lineHeight ?? lineHeight
        headerFont = other.headerFont ?? headerFont
        headerTextColor = other.headerTextColor ?? headerTextColor
        headerBackgroundColor = other.headerBackgroundColor ?? headerBackgroundColor
        rowEvenBackgroundColor = other.rowEvenBackgroundColor ?? rowEvenBackgroundColor
        rowOddBackgroundColor = other.rowOddBackgroundColor ?? rowOddBackgroundColor
        borderColor = other.borderColor ?? borderColor
        borderWidth = other.borderWidth ?? borderWidth
        borderRadius = other.borderRadius ?? borderRadius
        cellPaddingHorizontal = other.cellPaddingHorizontal ?? cellPaddingHorizontal
        cellPaddingVertical = other.cellPaddingVertical ?? cellPaddingVertical
        marginTop = other.marginTop ?? marginTop
        marginBottom = other.marginBottom ?? marginBottom
        align = other.align ?? align
    }
}
