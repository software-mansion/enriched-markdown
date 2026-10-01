import UIKit

public struct ThematicBreakStyle: Equatable, Sendable {
    public var color: UIColor?
    public var height: CGFloat?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?

    public init(
        color: UIColor? = nil,
        height: CGFloat? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil
    ) {
        self.color = color
        self.height = height
        self.marginTop = marginTop
        self.marginBottom = marginBottom
    }

    public mutating func merge(_ other: ThematicBreakStyle) {
        color = other.color ?? color
        height = other.height ?? height
        marginTop = other.marginTop ?? marginTop
        marginBottom = other.marginBottom ?? marginBottom
    }
}
