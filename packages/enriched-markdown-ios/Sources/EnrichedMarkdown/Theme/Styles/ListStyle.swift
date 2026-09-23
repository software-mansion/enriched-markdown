import UIKit

public struct ListStyle: Equatable, Sendable {
    public var font: UIFont?
    public var foregroundColor: UIColor?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var marginLeft: CGFloat?
    public var gapWidth: CGFloat?
    public var bulletColor: UIColor?
    public var bulletSize: CGFloat?
    public var markerMinWidth: CGFloat?
    public var markerColor: UIColor?

    public init(
        font: UIFont? = nil,
        foregroundColor: UIColor? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil,
        lineHeight: CGFloat? = nil,
        marginLeft: CGFloat? = nil,
        gapWidth: CGFloat? = nil,
        bulletColor: UIColor? = nil,
        bulletSize: CGFloat? = nil,
        markerMinWidth: CGFloat? = nil,
        markerColor: UIColor? = nil
    ) {
        self.font = font
        self.foregroundColor = foregroundColor
        self.marginTop = marginTop
        self.marginBottom = marginBottom
        self.lineHeight = lineHeight
        self.marginLeft = marginLeft
        self.gapWidth = gapWidth
        self.bulletColor = bulletColor
        self.bulletSize = bulletSize
        self.markerMinWidth = markerMinWidth
        self.markerColor = markerColor
    }

    public mutating func merge(_ other: ListStyle) {
        font = other.font ?? font
        foregroundColor = other.foregroundColor ?? foregroundColor
        marginTop = other.marginTop ?? marginTop
        marginBottom = other.marginBottom ?? marginBottom
        lineHeight = other.lineHeight ?? lineHeight
        marginLeft = other.marginLeft ?? marginLeft
        gapWidth = other.gapWidth ?? gapWidth
        bulletColor = other.bulletColor ?? bulletColor
        bulletSize = other.bulletSize ?? bulletSize
        markerMinWidth = other.markerMinWidth ?? markerMinWidth
        markerColor = other.markerColor ?? markerColor
    }
}
