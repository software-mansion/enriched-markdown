import SwiftUI

public struct BlockImage: MarkdownThemeContent {
    public var height: CGFloat?
    public var maxHeight: CGFloat?
    public var aspectRatio: CGFloat?
    public var resizeMode: ImageResizeMode?
    public var borderRadius: CGFloat?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?

    public init() {}

    public func height(_ value: CGFloat) -> Self {
        var copy = self
        copy.height = value
        return copy
    }

    /// Fits the image into at most `value` points of height, keeping its
    /// aspect ratio. Takes precedence over `height`; `0` clears it.
    public func maxHeight(_ value: CGFloat) -> Self {
        var copy = self
        copy.maxHeight = value
        return copy
    }

    /// Sizes the box from the available width and a width-over-height ratio,
    /// e.g. `16 / 9`. Takes precedence over `height` and `maxHeight`; `0` clears it.
    public func aspectRatio(_ value: CGFloat) -> Self {
        var copy = self
        copy.aspectRatio = value
        return copy
    }

    /// How the image fills its box. Defaults to `.cover` for `maxHeight` and
    /// `aspectRatio` boxes, and to fill-width drawing for a fixed `height`.
    public func resizeMode(_ value: ImageResizeMode) -> Self {
        var copy = self
        copy.resizeMode = value
        return copy
    }

    public func borderRadius(_ value: CGFloat) -> Self {
        var copy = self
        copy.borderRadius = value
        return copy
    }

    public func marginTop(_ value: CGFloat) -> Self {
        var copy = self
        copy.marginTop = value
        return copy
    }

    public func marginBottom(_ value: CGFloat) -> Self {
        var copy = self
        copy.marginBottom = value
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        if let height { config.image.height = height }
        if let maxHeight { config.image.maxHeight = maxHeight }
        if let aspectRatio { config.image.aspectRatio = aspectRatio }
        if let resizeMode { config.image.resizeMode = resizeMode }
        if let borderRadius { config.image.borderRadius = borderRadius }
        if let marginTop { config.image.marginTop = marginTop }
        if let marginBottom { config.image.marginBottom = marginBottom }
    }
}
