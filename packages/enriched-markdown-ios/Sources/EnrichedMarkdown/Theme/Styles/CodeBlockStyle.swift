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
    public var cornerRadius: CGFloat?
    public var borderWidth: CGFloat?
    /// Code blocks always lay out left-to-right; nil aligns to the left.
    public var textAlignment: NSTextAlignment?

    public init(
        font: UIFont? = nil,
        foregroundColor: UIColor? = nil,
        backgroundColor: UIColor? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil,
        lineHeight: CGFloat? = nil,
        padding: CGFloat? = nil,
        borderColor: UIColor? = nil,
        cornerRadius: CGFloat? = nil,
        borderWidth: CGFloat? = nil,
        textAlignment: NSTextAlignment? = nil
    ) {
        self.font = font
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.marginTop = marginTop
        self.marginBottom = marginBottom
        self.lineHeight = lineHeight
        self.padding = padding
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.textAlignment = textAlignment
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
        cornerRadius = other.cornerRadius ?? cornerRadius
        borderWidth = other.borderWidth ?? borderWidth
        textAlignment = other.textAlignment ?? textAlignment
    }
}
