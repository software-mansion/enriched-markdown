import SwiftUI

private struct MarkdownSelectableKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

private struct MarkdownSelectionColorKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

public extension EnvironmentValues {
    var markdownSelectable: Bool {
        get { self[MarkdownSelectableKey.self] }
        set { self[MarkdownSelectableKey.self] = newValue }
    }

    var markdownSelectionColor: Color? {
        get { self[MarkdownSelectionColorKey.self] }
        set { self[MarkdownSelectionColorKey.self] = newValue }
    }
}

public extension View {
    /// Controls whether the rendered markdown text can be selected, with
    /// SwiftUI's `.enabled` / `.disabled` selectability. Defaults to
    /// enabled. Links remain tappable when selection is disabled.
    func markdownTextSelection<Selectability: TextSelectability>(_ selectability: Selectability) -> some View {
        environment(\.markdownSelectable, Selectability.allowsSelection)
    }

    /// Tint for the selection highlight, handles, and caret — UIKit derives
    /// all three from a single tint. `nil` keeps the system tint.
    func markdownSelectionColor(_ color: Color?) -> some View {
        environment(\.markdownSelectionColor, color)
    }
}
