import CryptoKit
import Foundation

enum ImageCacheKey {
    /// Returns the URL unchanged when no headers are set; otherwise appends a
    /// SHA-256 digest of the sorted header pairs, so the same URL fetched with
    /// different headers is cached and deduplicated separately without
    /// embedding header values in the key. Matches the Android
    /// implementation (`ImageCache.requestKey`) byte for byte.
    static func requestKey(url: String, headers: [String: String]) -> String {
        guard !headers.isEmpty else { return url }
        let joined = headers
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: "\n")
        let digest = SHA256.hash(data: Data(joined.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return url + "|" + hex
    }
}
