import SwiftUI

public struct BlockImage: MarkdownThemeContent {
    public var sizing: ImageSizing?
    public var contentMode: ImageContentMode?
    public var borderRadius: CGFloat?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?

    public init() {}

    /// A fixed box height.
    public func height(_ value: CGFloat) -> Self {
        sizing(.height(value))
    }

    /// Fits the image at the available width, capped at `value` points of height.
    public func maxHeight(_ value: CGFloat) -> Self {
        sizing(.maxHeight(value))
    }

    /// Sizes the box from the available width and a width-over-height ratio, e.g. `16 / 9`.
    public func aspectRatio(_ ratio: CGFloat) -> Self {
        sizing(.aspectRatio(ratio))
    }

    public func aspectRatio(_ size: CGSize) -> Self {
        aspectRatio(size.width / size.height)
    }

    /// `aspectRatio(ratio).contentMode(contentMode)`. Unlike SwiftUI's modifier,
    /// the ratio shapes the box and the mode places the image inside it.
    public func aspectRatio(_ ratio: CGFloat, contentMode: ImageContentMode) -> Self {
        aspectRatio(ratio).contentMode(contentMode)
    }

    /// How the image fills its box. Left unset, a `height` box draws
    /// `.fitWidth` and a `maxHeight` or `aspectRatio` box `.fill`.
    public func contentMode(_ value: ImageContentMode) -> Self {
        var copy = self
        copy.contentMode = value
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
        if let sizing { config.image.sizing = sizing }
        if let contentMode { config.image.contentMode = contentMode }
        if let borderRadius { config.image.borderRadius = borderRadius }
        if let marginTop { config.image.marginTop = marginTop }
        if let marginBottom { config.image.marginBottom = marginBottom }
    }

    private func sizing(_ value: ImageSizing) -> Self {
        var copy = self
        copy.sizing = value
        return copy
    }
}
