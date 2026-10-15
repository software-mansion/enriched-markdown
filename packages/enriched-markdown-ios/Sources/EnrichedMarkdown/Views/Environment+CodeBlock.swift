import SwiftUI

public enum MarkdownCodeBlockLayout: Equatable, Sendable {
    /// Lines wrap and the code is selectable text. The default.
    case wrapping
    /// A panel with a language header and copy button; lines keep their length and scroll sideways.
    case scrollable
}

public struct CodeBlockCopy: Equatable, Sendable {
    public let code: String
    public let language: String?

    public init(code: String, language: String?) {
        self.code = code
        self.language = language
    }
}

private struct MarkdownCodeBlockLayoutKey: EnvironmentKey {
    static let defaultValue: MarkdownCodeBlockLayout = .wrapping
}

private struct MarkdownCodeBlockCopyHandlerKey: EnvironmentKey {
    static let defaultValue: ((CodeBlockCopy) -> Void)? = nil
}

public extension EnvironmentValues {
    var markdownCodeBlockLayout: MarkdownCodeBlockLayout {
        get { self[MarkdownCodeBlockLayoutKey.self] }
        set { self[MarkdownCodeBlockLayoutKey.self] = newValue }
    }

    var markdownCodeBlockCopyHandler: ((CodeBlockCopy) -> Void)? {
        get { self[MarkdownCodeBlockCopyHandlerKey.self] }
        set { self[MarkdownCodeBlockCopyHandlerKey.self] = newValue }
    }
}

public extension View {
    func markdownCodeBlockLayout(_ layout: MarkdownCodeBlockLayout) -> some View {
        environment(\.markdownCodeBlockLayout, layout)
    }

    /// Called after the copy button, the long-press Copy or the VoiceOver action copies a block; not for Copy as Markdown.
    func onCodeBlockCopy(_ action: @escaping (CodeBlockCopy) -> Void) -> some View {
        environment(\.markdownCodeBlockCopyHandler, action)
    }
}
