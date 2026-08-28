import SwiftUI

public struct Subscript: MarkdownThemeContent {
    public var fontScale: CGFloat?
    public var baselineOffsetScale: CGFloat?

    public init() {}

    /// Font size as a fraction of the surrounding text size.
    public func fontScale(_ value: CGFloat) -> Self {
        var copy = self
        copy.fontScale = value
        return copy
    }

    /// Downward baseline shift as a fraction of the surrounding text size.
    public func baselineOffsetScale(_ value: CGFloat) -> Self {
        var copy = self
        copy.baselineOffsetScale = value
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        if let fontScale { config.subscript.fontScale = fontScale }
        if let baselineOffsetScale { config.subscript.baselineOffsetScale = baselineOffsetScale }
    }
}
