import UIKit

/// How a block image's box height is derived. A theme sets exactly one: the
/// last sizing modifier applied wins, and a theme layer that sets any sizing
/// replaces the lower layer's.
public enum ImageSizing: Equatable, Sendable {
    /// A fixed box height in points.
    case height(CGFloat)
    /// The image's own proportions at the available width, capped at this
    /// height.
    case maxHeight(CGFloat)
    /// The available width over this width-to-height ratio, e.g. `16 / 9`.
    case aspectRatio(CGFloat)
}

/// How a block image's bitmap fills the box laid out for it.
public enum ImageContentMode: String, CaseIterable, Equatable, Sendable {
    /// Scales to fit inside the box, keeping the aspect ratio. Never crops.
    case fit
    /// Scales to fill the box, keeping the aspect ratio. Overflow is cropped.
    case fill
    /// Fills the box exactly, ignoring the aspect ratio.
    case stretch
    /// Draws centered at its own size, scaled down only when it exceeds the box.
    case scaleDown
    /// Draws centered at its own size, never scaled. Overflow is cropped.
    case original
    /// Scales to the box width and centers vertically; overflow is cropped.
    /// The default drawing of a fixed-`height` box.
    case fitWidth
}

public struct ImageStyle: Equatable, Sendable {
    /// See `BlockImage.height(_:)`, `maxHeight(_:)` and `aspectRatio(_:)`.
    public var sizing: ImageSizing?
    /// See `BlockImage.contentMode(_:)`.
    public var contentMode: ImageContentMode?
    public var borderRadius: CGFloat?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?

    /// The fixed box height, when `sizing` is one. Setting it replaces the sizing.
    public var height: CGFloat? {
        get {
            guard case .height(let value) = sizing else { return nil }
            return value
        }
        set { sizing = newValue.map(ImageSizing.height) }
    }

    public init(
        sizing: ImageSizing? = nil,
        contentMode: ImageContentMode? = nil,
        borderRadius: CGFloat? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil
    ) {
        self.sizing = sizing
        self.contentMode = contentMode
        self.borderRadius = borderRadius
        self.marginTop = marginTop
        self.marginBottom = marginBottom
    }

    public mutating func merge(_ other: ImageStyle) {
        sizing = other.sizing ?? sizing
        contentMode = other.contentMode ?? contentMode
        borderRadius = other.borderRadius ?? borderRadius
        marginTop = other.marginTop ?? marginTop
        marginBottom = other.marginBottom ?? marginBottom
    }
}

public struct InlineImageStyle: Equatable, Sendable {
    public var size: CGFloat?

    public init(size: CGFloat? = nil) {
        self.size = size
    }

    public mutating func merge(_ other: InlineImageStyle) {
        size = other.size ?? size
    }
}
