import SwiftUI

/// Configuration for the custom items added to the text-selection edit menu.
public struct MarkdownSelectionMenuConfig: Equatable, Sendable {
    public var copyAsMarkdown: Bool
    public var copyImageUrl: Bool
    public var copyAsMarkdownLabel: String

    public init(
        copyAsMarkdown: Bool = true,
        copyImageUrl: Bool = true,
        copyAsMarkdownLabel: String = "Copy as Markdown"
    ) {
        self.copyAsMarkdown = copyAsMarkdown
        self.copyImageUrl = copyImageUrl
        self.copyAsMarkdownLabel = copyAsMarkdownLabel
    }
}

private struct MarkdownSelectionMenuKey: EnvironmentKey {
    static let defaultValue = MarkdownSelectionMenuConfig()
}

public extension EnvironmentValues {
    var markdownSelectionMenu: MarkdownSelectionMenuConfig {
        get { self[MarkdownSelectionMenuKey.self] }
        set { self[MarkdownSelectionMenuKey.self] = newValue }
    }
}

public extension View {
    /// Configures the custom edit-menu items ("Copy as Markdown",
    /// "Copy Image URL") shown when text is selected. Requires iOS 16;
    /// earlier versions keep the stock menu.
    func markdownSelectionMenu(_ config: MarkdownSelectionMenuConfig) -> some View {
        environment(\.markdownSelectionMenu, config)
    }
}
