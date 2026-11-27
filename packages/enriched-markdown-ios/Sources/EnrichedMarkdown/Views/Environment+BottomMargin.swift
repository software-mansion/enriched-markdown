import SwiftUI

private struct MarkdownBottomMarginVisibilityKey: EnvironmentKey {
    static let defaultValue: Visibility = .automatic
}

public extension EnvironmentValues {
    var markdownBottomMarginVisibility: Visibility {
        get { self[MarkdownBottomMarginVisibilityKey.self] }
        set { self[MarkdownBottomMarginVisibilityKey.self] = newValue }
    }
}

public extension View {
    func markdownBottomMargin(_ visibility: Visibility) -> some View {
        environment(\.markdownBottomMarginVisibility, visibility)
    }
}
