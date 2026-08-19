import SwiftUI

private struct MarkdownImageRequestHeadersKey: EnvironmentKey {
    static let defaultValue: [String: String] = [:]
}

public extension EnvironmentValues {
    var markdownImageRequestHeaders: [String: String] {
        get { self[MarkdownImageRequestHeadersKey.self] }
        set { self[MarkdownImageRequestHeadersKey.self] = newValue }
    }
}

public extension View {
    /// Custom HTTP headers sent with every markdown image request, e.g. for
    /// authenticated CDNs. The same URL fetched with different headers is
    /// cached separately.
    func markdownImageRequestHeaders(_ headers: [String: String]) -> some View {
        environment(\.markdownImageRequestHeaders, headers)
    }
}
