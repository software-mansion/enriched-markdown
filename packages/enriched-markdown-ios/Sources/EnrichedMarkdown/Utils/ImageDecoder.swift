import ImageIO
import UIKit

enum ImageDecoder {
    /// Decodes image data downsampled so its longer side is at most
    /// `maxPixelSize` (screen pixel width by default), so large images never
    /// decode at full size. Never upscales.
    /// The result carries the screen scale so point-size math downstream is
    /// unchanged, and EXIF orientation is baked in.
    static func decodeDownsampled(
        _ data: Data,
        maxPixelSize: CGFloat = UIScreen.main.bounds.width * UIScreen.main.scale,
        scale: CGFloat = UIScreen.main.scale
    ) -> UIImage? {
        guard !data.isEmpty else { return nil }

        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}
