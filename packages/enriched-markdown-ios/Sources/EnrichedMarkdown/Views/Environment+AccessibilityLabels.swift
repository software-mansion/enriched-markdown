import SwiftUI

private struct MarkdownAccessibilityLabelsKey: EnvironmentKey {
    static let defaultValue: MarkdownAccessibilityLabels = .default
}

public extension EnvironmentValues {
    var markdownAccessibilityLabels: MarkdownAccessibilityLabels {
        get { self[MarkdownAccessibilityLabelsKey.self] }
        set { self[MarkdownAccessibilityLabelsKey.self] = newValue }
    }
}

public extension View {
    /// Overrides the strings VoiceOver speaks for list items, blockquotes,
    /// table rows, images without alt text, the code block copy action, and
    /// rotor names. Defaults are English.
    func markdownAccessibilityLabels(_ labels: MarkdownAccessibilityLabels) -> some View {
        environment(\.markdownAccessibilityLabels, labels)
    }
}
