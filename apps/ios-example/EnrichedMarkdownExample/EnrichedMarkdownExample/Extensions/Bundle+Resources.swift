import UIKit

extension Bundle {
    /// Sample document rendered by the Text screen.
    var sampleMarkdown: String {
        guard
            let url = url(forResource: "sample_markdown", withExtension: "md"),
            let content = try? String(contentsOf: url, encoding: .utf8)
        else {
            return ""
        }
        return content
    }

    /// Long-form science article rendered by the Article screen.
    var articleMarkdown: String {
        guard
            let url = url(forResource: "article_markdown", withExtension: "md"),
            let content = try? String(contentsOf: url, encoding: .utf8)
        else {
            return ""
        }
        return content
    }

    /// Loose bundled PNG — the article's figures ship as files, not as
    /// asset-catalog entries, so the markdown can reference them by name.
    ///
    /// Decoded once and kept. `UIImage(contentsOfFile:)` re-reads and
    /// re-inflates the file on every call, and SwiftUI calls this from a
    /// `body` that a parallax offset re-evaluates on every frame of a scroll.
    func pngImage(named name: String) -> UIImage? {
        BundledImageCache.shared.image(named: name) {
            url(forResource: name, withExtension: "png").flatMap { UIImage(contentsOfFile: $0.path) }
        }
    }

    /// `file://` URI for a bundled image, used to insert image markdown in the playground.
    func imageURI(named name: String, extension ext: String) -> String? {
        url(forResource: name, withExtension: ext)?.absoluteString
    }
}

/// Decoded bundle images, kept for the life of the process.
///
/// Misses are cached too: a name that does not resolve must not send every
/// later call back to the file system.
private final class BundledImageCache {
    static let shared = BundledImageCache()

    private var images: [String: UIImage?] = [:]
    private let lock = NSLock()

    func image(named name: String, load: () -> UIImage?) -> UIImage? {
        lock.lock()
        if let cached = images[name] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let loaded = load()

        lock.lock()
        images[name] = loaded
        lock.unlock()
        return loaded
    }
}
