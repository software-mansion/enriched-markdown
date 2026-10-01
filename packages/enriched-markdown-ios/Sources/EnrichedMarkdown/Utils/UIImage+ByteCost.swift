import UIKit

extension UIImage {
    /// Decoded size in bytes, for weighing entries against an `NSCache` cost limit.
    var byteCost: Int {
        guard let cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
