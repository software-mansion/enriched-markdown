import UIKit

/// The box a block image is laid out in, derived from its theme sizing.
extension ImageSizing {
    /// Stands in wherever the real height cannot be known: no theme sizing at
    /// all, or a ratio box before the container width is.
    static let fallbackHeight: CGFloat = 200

    /// The box height for a container `width`. `intrinsicSize` is the loaded
    /// image's own size, or nil before it loads — `maxHeight` then answers the
    /// cap and settles once the image arrives.
    func boxHeight(width: CGFloat, intrinsicSize: CGSize?) -> CGFloat {
        switch self {
        case .height(let height):
            return height
        case .aspectRatio(let ratio):
            guard width > 0, ratio > 0, ratio.isFinite else { return Self.fallbackHeight }
            return width / ratio
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
    var defaultContentMode: ImageContentMode {
        if case .height = self { return .fitWidth }
        return .fill
    }
}

/// Where an image's bitmap is drawn inside the box laid out for it.
enum ImageDrawing {
    /// The rect to draw `source` into, within a box of `box` at the origin.
    static func rect(mode: ImageContentMode, source: CGSize, box: CGSize) -> CGRect {
        guard source.width > 0, source.height > 0 else {
            return CGRect(origin: .zero, size: box)
        }

        let widthScale = box.width / source.width
        let heightScale = box.height / source.height

        let scale: CGFloat
        switch mode {
        case .fitWidth:
            scale = widthScale
        case .stretch:
            return CGRect(origin: .zero, size: box)
        case .fit:
            scale = min(widthScale, heightScale)
        case .fill:
            scale = max(widthScale, heightScale)
        case .scaleDown:
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
