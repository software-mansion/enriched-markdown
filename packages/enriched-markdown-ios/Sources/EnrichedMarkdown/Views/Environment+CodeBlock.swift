import SwiftUI

/// How fenced code blocks are laid out.
public enum MarkdownCodeBlockLayout: Equatable, Sendable {
    /// The code is part of the document's text: lines wrap at the view's
    /// width and take part in text selection. The default.
    case wrapping
    /// Each block is a panel with a header naming the language and a copy
    /// button; lines keep their length and the panel scrolls sideways.
    /// Text selection treats the panel as one character; long-pressing it
    /// offers Copy and Copy as Markdown.
    case scrollable
}

/// Payload for `onCodeBlockCopy`: the copied code and the fence's language,
/// nil when the fence named none.
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
    /// Lays fenced code blocks out as wrapping text (the default) or as
    /// scrollable panels with a language header and copy button.
    func markdownCodeBlockLayout(_ layout: MarkdownCodeBlockLayout) -> some View {
        environment(\.markdownCodeBlockLayout, layout)
    }

    /// Called after a code block's code is copied: by the panel's copy
    /// button, its long-press **Copy**, or the VoiceOver copy action. Not
    /// called for Copy as Markdown.
    func onCodeBlockCopy(_ action: @escaping (CodeBlockCopy) -> Void) -> some View {
        environment(\.markdownCodeBlockCopyHandler, action)
    }
}
