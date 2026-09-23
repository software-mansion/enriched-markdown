import SwiftUI

private struct MarkdownLinkPressHandlerKey: EnvironmentKey {
    static let defaultValue: ((URL) -> Void)? = nil
}

private struct MarkdownLinkLongPressHandlerKey: EnvironmentKey {
    static let defaultValue: ((URL) -> Void)? = nil
}

public extension EnvironmentValues {
    /// Installed by the deprecated `onLinkPress`; when set it takes every
    /// link tap (and long-press, absent a long-press handler) instead of
    /// the `openURL` action.
    var markdownLinkPressHandler: ((URL) -> Void)? {
        get { self[MarkdownLinkPressHandlerKey.self] }
        set { self[MarkdownLinkPressHandlerKey.self] = newValue }
    }

    var markdownLinkLongPressHandler: ((URL) -> Void)? {
        get { self[MarkdownLinkLongPressHandlerKey.self] }
        set { self[MarkdownLinkLongPressHandlerKey.self] = newValue }
    }
}

public extension View {
    /// Called when a link is long-pressed, replacing the system link menu.
    /// Taps go through the `openURL` environment action, as SwiftUI's own
    /// `Text` links do:
    ///
    /// ```swift
    /// EnrichedMarkdownText(markdown)
    ///     .environment(\.openURL, OpenURLAction { url in
    ///         route(url)
    ///         return .handled
    ///     })
    ///     .onMarkdownLinkLongPress { url in share(url) }
    /// ```
    func onMarkdownLinkLongPress(_ action: @escaping (URL) -> Void) -> some View {
        environment(\.markdownLinkLongPressHandler, action)
    }
}
