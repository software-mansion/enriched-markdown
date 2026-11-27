import CryptoKit
import Foundation

enum ImageCacheKey {
    /// Header names lower-cased; sorted first so case aliases collapse deterministically.
    static func normalizedHeaders(_ headers: [String: String]) -> [String: String] {
        var normalized: [String: String] = [:]
        for (name, value) in headers.sorted(by: { $0.key < $1.key }) {
            normalized[name.lowercased()] = value
        }
        return normalized
    }

    /// Returns the URL unchanged when no headers are set; otherwise appends a
    /// SHA-256 digest of the sorted header pairs, so the same URL fetched with
    /// different headers is cached and deduplicated separately without
    /// embedding header values in the key. Header names are compared
    /// case-insensitively. The key format (sorted `key:value` pairs joined with
    /// newlines, hashed to hex) is shared across platforms — keep it stable.
    static func requestKey(url: String, headers: [String: String]) -> String {
        guard !headers.isEmpty else { return url }
        let joined = normalizedHeaders(headers)
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: "\n")
        let digest = SHA256.hash(data: Data(joined.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return url + "|" + hex
    }
}
