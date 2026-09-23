import UIKit

public struct CodeBlockStyle: Equatable, Sendable {
    public var font: UIFont?
    public var foregroundColor: UIColor?
    public var backgroundColor: UIColor?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var padding: CGFloat?
    public var borderColor: UIColor?
    public var borderRadius: CGFloat?
    public var borderWidth: CGFloat?

    public init(
        font: UIFont? = nil,
        foregroundColor: UIColor? = nil,
        backgroundColor: UIColor? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil,
        lineHeight: CGFloat? = nil,
        padding: CGFloat? = nil,
        borderColor: UIColor? = nil,
        borderRadius: CGFloat? = nil,
        borderWidth: CGFloat? = nil
    ) {
        self.font = font
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.marginTop = marginTop
        self.marginBottom = marginBottom
        self.lineHeight = lineHeight
        self.padding = padding
        self.borderColor = borderColor
        self.borderRadius = borderRadius
        self.borderWidth = borderWidth
    }

    public mutating func merge(_ other: CodeBlockStyle) {
        font = other.font ?? font
        foregroundColor = other.foregroundColor ?? foregroundColor
        backgroundColor = other.backgroundColor ?? backgroundColor
        marginTop = other.marginTop ?? marginTop
        marginBottom = other.marginBottom ?? marginBottom
        lineHeight = other.lineHeight ?? lineHeight
        padding = other.padding ?? padding
        borderColor = other.borderColor ?? borderColor
        borderRadius = other.borderRadius ?? borderRadius
        borderWidth = other.borderWidth ?? borderWidth
    }
}
