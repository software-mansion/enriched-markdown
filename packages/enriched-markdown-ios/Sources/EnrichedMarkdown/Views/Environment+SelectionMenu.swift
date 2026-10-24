import SwiftUI

/// The custom items added to the text-selection edit menu.
public struct MarkdownSelectionMenu: Equatable, Sendable {
    public var copyAsMarkdown: Bool
    public var copyImageURL: Bool
    public var copyAsMarkdownLabel: String

    public init(
        copyAsMarkdown: Bool = true,
        copyImageURL: Bool = true,
        copyAsMarkdownLabel: String = "Copy as Markdown"
    ) {
        self.copyAsMarkdown = copyAsMarkdown
        self.copyImageURL = copyImageURL
        self.copyAsMarkdownLabel = copyAsMarkdownLabel
    }
}

private struct MarkdownSelectionMenuKey: EnvironmentKey {
    static let defaultValue = MarkdownSelectionMenu()
}

public extension EnvironmentValues {
    var markdownSelectionMenu: MarkdownSelectionMenu {
        get { self[MarkdownSelectionMenuKey.self] }
        set { self[MarkdownSelectionMenuKey.self] = newValue }
    }
}

public extension View {
    /// Configures the custom edit-menu items ("Copy as Markdown",
    /// "Copy Image URL") shown when text is selected.
    func markdownSelectionMenu(_ menu: MarkdownSelectionMenu) -> some View {
        environment(\.markdownSelectionMenu, menu)
    }
}
