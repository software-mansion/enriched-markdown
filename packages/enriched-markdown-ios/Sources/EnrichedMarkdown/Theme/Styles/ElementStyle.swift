import UIKit

public struct ElementStyle: Equatable, Sendable {
    public var font: UIFont?
    public var foregroundColor: UIColor?
    public var backgroundColor: UIColor?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var textAlignment: NSTextAlignment?
    public var underline: Bool?

    public init(
        font: UIFont? = nil,
        foregroundColor: UIColor? = nil,
        backgroundColor: UIColor? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil,
        lineHeight: CGFloat? = nil,
        textAlignment: NSTextAlignment? = nil,
        underline: Bool? = nil
    ) {
        self.font = font
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.marginTop = marginTop
        self.marginBottom = marginBottom
        self.lineHeight = lineHeight
        self.textAlignment = textAlignment
        self.underline = underline
    }

    public mutating func merge(_ other: ElementStyle) {
        font = other.font ?? font
        foregroundColor = other.foregroundColor ?? foregroundColor
        backgroundColor = other.backgroundColor ?? backgroundColor
        marginTop = other.marginTop ?? marginTop
        marginBottom = other.marginBottom ?? marginBottom
        lineHeight = other.lineHeight ?? lineHeight
        textAlignment = other.textAlignment ?? textAlignment
        underline = other.underline ?? underline
    }
}
