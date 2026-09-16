import UIKit

/// The box-height policy of a block image, resolved from `ImageStyle`.
///
/// Precedence is `aspectRatio`, then `maxHeight`, then `height`; a knob set to
/// zero or less counts as unset, so a theme layer can switch a lower layer's
/// responsive sizing back off.
enum ImageBoxSizing: Equatable {
    case fixed(height: CGFloat)
    /// A box fitted to the image's own proportions, capped at this height.
    case maxHeight(CGFloat)
    /// A box whose height is the available width over this ratio.
    case aspectRatio(CGFloat)

    /// Stands in wherever the real height cannot be known: no theme height at
    /// all, or a ratio box before the container width is.
    static let fallbackHeight: CGFloat = 200

    init(style: ImageStyle) {
        if let ratio = style.aspectRatio, ratio > 0 {
            self = .aspectRatio(ratio)
        } else if let cap = style.maxHeight, cap > 0 {
            self = .maxHeight(cap)
        } else {
            self = .fixed(height: style.height ?? Self.fallbackHeight)
        }
    }

    /// The box height for a container `width`. `intrinsicSize` is the loaded
    /// image's own size, or nil before it loads — `maxHeight` then answers the
    /// cap and settles once the image arrives.
    func boxHeight(width: CGFloat, intrinsicSize: CGSize?) -> CGFloat {
        switch self {
        case .fixed(let height):
            return height
        case .aspectRatio(let ratio):
            return width > 0 ? width / ratio : Self.fallbackHeight
        case .maxHeight(let cap):
            guard width > 0,
                  let size = intrinsicSize,
                  size.width > 0,
                  size.height > 0 else { return cap }
            return min(cap, width * size.height / size.width)
        }
    }

    /// The height to stand a box at before it has ever been laid out.
    var placeholderHeight: CGFloat {
        boxHeight(width: 0, intrinsicSize: nil)
    }

    /// How the bitmap fills a box whose theme set no explicit mode.
    var defaultResizeMode: ImageResizeMode? {
        if case .fixed = self { return nil }
        return .cover
    }
}

/// Where an image's bitmap is drawn inside the box laid out for it.
enum ImageDrawing {
    /// The rect to draw `source` into, within a box of `box` at the origin.
    ///
    /// A nil `mode` is the legacy drawing: scaled to the box width and
    /// centered vertically, overflowing the box when the image is taller.
    static func rect(mode: ImageResizeMode?, source: CGSize, box: CGSize) -> CGRect {
        guard source.width > 0, source.height > 0 else {
            return CGRect(origin: .zero, size: box)
        }

        let widthScale = box.width / source.width
        let heightScale = box.height / source.height

        let scale: CGFloat
        switch mode {
        case .none:
            return centered(size: CGSize(width: box.width, height: source.height * widthScale), in: box)
        case .stretch:
            return CGRect(origin: .zero, size: box)
        case .contain:
            scale = min(widthScale, heightScale)
        case .cover:
            scale = max(widthScale, heightScale)
        case .center:
            scale = min(1, min(widthScale, heightScale))
        case .original:
            scale = 1
        }

        return centered(
            size: CGSize(width: source.width * scale, height: source.height * scale),
            in: box
        )
    }

    private static func centered(size: CGSize, in box: CGSize) -> CGRect {
        CGRect(
            x: (box.width - size.width) / 2,
            y: (box.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }
}
