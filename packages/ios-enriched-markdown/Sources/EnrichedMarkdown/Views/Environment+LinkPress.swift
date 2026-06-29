import SwiftUI

private struct MarkdownLinkPressHandlerKey: EnvironmentKey {
    static let defaultValue: ((URL) -> Void)? = nil
}

public extension EnvironmentValues {
    var markdownLinkPressHandler: ((URL) -> Void)? {
        get { self[MarkdownLinkPressHandlerKey.self] }
        set { self[MarkdownLinkPressHandlerKey.self] = newValue }
    }
}

public extension View {
    func onLinkPress(_ action: @escaping (URL) -> Void) -> some View {
        environment(\.markdownLinkPressHandler, action)
    }
}
