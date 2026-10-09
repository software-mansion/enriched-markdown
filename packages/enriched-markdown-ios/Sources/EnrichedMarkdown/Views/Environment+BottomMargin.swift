import SwiftUI

private struct MarkdownBottomMarginEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

public extension EnvironmentValues {
    var markdownBottomMarginEnabled: Bool {
        get { self[MarkdownBottomMarginEnabledKey.self] }
        set { self[MarkdownBottomMarginEnabledKey.self] = newValue }
    }
}

public extension View {
    /// Keeps the last block's bottom margin below the text; off by default.
    func markdownBottomMarginEnabled(_ enabled: Bool) -> some View {
        environment(\.markdownBottomMarginEnabled, enabled)
    }
}
