import UIKit

/// Colors for one GitHub alert type; everything else comes from the
/// enclosing `BlockquoteStyle`.
public struct AdmonitionStyle: Equatable, Sendable {
    /// Tints the accent bar, the icon, and the title; nil falls back to the
    /// blockquote border color.
    public var color: UIColor?
    /// Fills the callout; nil leaves it unfilled.
    public var backgroundColor: UIColor?

    public init(color: UIColor? = nil, backgroundColor: UIColor? = nil) {
        self.color = color
        self.backgroundColor = backgroundColor
    }

    public mutating func merge(_ other: AdmonitionStyle) {
        color = other.color ?? color
        backgroundColor = other.backgroundColor ?? backgroundColor
    }
}
