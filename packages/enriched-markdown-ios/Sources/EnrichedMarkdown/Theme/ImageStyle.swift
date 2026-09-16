import UIKit

/// How a block image's bitmap fills the box laid out for it.
///
/// Leaving `ImageStyle.resizeMode` unset keeps the legacy drawing: the image is
/// scaled to the box width, centered vertically, and any overflow is clipped.
public enum ImageResizeMode: String, Equatable, Sendable {
    /// Scales to fit inside the box, keeping the aspect ratio. Never crops.
    case contain
    /// Scales to fill the box, keeping the aspect ratio. Overflow is cropped.
    case cover
    /// Fills the box exactly, ignoring the aspect ratio.
    case stretch
    /// Draws centered at its own size, scaled down only when it exceeds the box.
    case center
    /// Draws centered at its own size, never scaled. Overflow is cropped.
    case original
}

public struct ImageStyle: Equatable, Sendable {
    /// See `BlockImage.height(_:)`.
    public var height: CGFloat?
    /// See `BlockImage.maxHeight(_:)`.
    public var maxHeight: CGFloat?
    /// See `BlockImage.aspectRatio(_:)`.
    public var aspectRatio: CGFloat?
    /// See `BlockImage.resizeMode(_:)`.
    public var resizeMode: ImageResizeMode?
    public var borderRadius: CGFloat?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?

    public init(
        height: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        aspectRatio: CGFloat? = nil,
        resizeMode: ImageResizeMode? = nil,
        borderRadius: CGFloat? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil
    ) {
        self.height = height
        self.maxHeight = maxHeight
        self.aspectRatio = aspectRatio
        self.resizeMode = resizeMode
        self.borderRadius = borderRadius
        self.marginTop = marginTop
        self.marginBottom = marginBottom
    }

    public mutating func merge(_ other: ImageStyle) {
        height = other.height ?? height
        maxHeight = other.maxHeight ?? maxHeight
        aspectRatio = other.aspectRatio ?? aspectRatio
        resizeMode = other.resizeMode ?? resizeMode
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
