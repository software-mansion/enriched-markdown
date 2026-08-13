import SwiftUI

private struct MarkdownLinkPressHandlerKey: EnvironmentKey {
    static let defaultValue: ((URL) -> Void)? = nil
}

private struct MarkdownLinkLongPressHandlerKey: EnvironmentKey {
    static let defaultValue: ((URL) -> Void)? = nil
}

public extension EnvironmentValues {
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
    func onLinkPress(_ action: @escaping (URL) -> Void) -> some View {
        environment(\.markdownLinkPressHandler, action)
    }

    /// Called when a link is long-pressed, replacing the system link menu.
    /// Without this handler, a long-press behaves like a press when
    /// `onLinkPress` is set.
    func onLinkLongPress(_ action: @escaping (URL) -> Void) -> some View {
        environment(\.markdownLinkLongPressHandler, action)
    }
}
