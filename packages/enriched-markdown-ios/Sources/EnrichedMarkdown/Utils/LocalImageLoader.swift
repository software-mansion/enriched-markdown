import UIKit
import os.log

/// Loads markdown images from non-network sources:
/// - `file://` URIs (including percent-encoded paths)
/// - absolute file paths
/// - `data:` URIs (base64 payloads)
/// - bare names resolved as bundled image resources, with a normalized
///   fallback (lowercase, `-` → `_`) so the same markdown resolves across
///   platforms
///
/// Sources with no iOS equivalent (`content://`, `asset://`, `res://`) log
/// and return nil. All decodes are downsampled to screen width like the
/// network path; asset-catalog images are the exception (no file URL to
/// decode from) and load through `UIImage(named:)` as-is.
enum LocalImageLoader {
    private static let base64Marker = "base64,"
    private static let resourceExtensions = ["png", "jpg", "jpeg", "gif", "heic"]

    static func load(_ source: String, bundle: Bundle = .main) -> UIImage? {
        guard !source.isEmpty else { return nil }

        if source.hasPrefix("/") {
            return decodeFile(atPath: source)
        }

        switch URLComponents(string: source)?.scheme?.lowercased() {
        case nil:
            return decodeResource(named: source, bundle: bundle)
        case "file":
            guard let path = URL(string: source)?.path, !path.isEmpty else { return nil }
            return decodeFile(atPath: path)
        case "data":
            return decodeDataURI(source)
        default:
            os_log(.info, "EnrichedMarkdown: unsupported image URI scheme: %{public}@", source)
            return nil
        }
    }

    /// Resource-name normalization: lowercase with `-` replaced by `_`, so
    /// the same markdown resolves across platforms.
    static func normalizedResourceName(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: "-", with: "_")
    }

    private static func decodeFile(atPath path: String) -> UIImage? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return ImageDecoder.decodeDownsampled(data)
    }

    private static func decodeDataURI(_ source: String) -> UIImage? {
        guard let marker = source.range(of: base64Marker) else { return nil }
        let payload = String(source[marker.upperBound...])
        guard let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters) else {
            return nil
        }
        return ImageDecoder.decodeDownsampled(data)
    }

    private static func decodeResource(named name: String, bundle: Bundle) -> UIImage? {
        var candidates = [name]
        let normalized = normalizedResourceName(name)
        if normalized != name {
            candidates.append(normalized)
        }

        for candidate in candidates {
            if let url = resourceURL(for: candidate, bundle: bundle),
               let data = try? Data(contentsOf: url) {
                return ImageDecoder.decodeDownsampled(data)
            }
        }

        // Asset catalogs expose no file URL to decode from; UIImage(named:)
        // covers them (right-sized variants, no downsampling needed).
        for candidate in candidates {
            if let image = UIImage(named: candidate, in: bundle, compatibleWith: nil) {
                return image
            }
        }

        os_log(.info, "EnrichedMarkdown: no bundled image resource named: %{public}@", name)
        return nil
    }

    private static func resourceURL(for name: String, bundle: Bundle) -> URL? {
        let ext = (name as NSString).pathExtension
        guard ext.isEmpty else {
            return bundle.url(
                forResource: (name as NSString).deletingPathExtension,
                withExtension: ext
            )
        }
        for candidateExtension in resourceExtensions {
            if let url = bundle.url(forResource: name, withExtension: candidateExtension) {
                return url
            }
        }
        return nil
    }
}
