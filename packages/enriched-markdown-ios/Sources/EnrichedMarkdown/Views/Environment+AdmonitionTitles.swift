import SwiftUI

/// Header titles for GitHub alerts (`> [!NOTE]`, …). Every type defaults to
/// its English name; an empty title shows the icon only.
public struct MarkdownAdmonitionTitles: Equatable, Sendable {
    public var note: String
    public var tip: String
    public var important: String
    public var warning: String
    public var caution: String

    public init(
        note: String = "Note",
        tip: String = "Tip",
        important: String = "Important",
        warning: String = "Warning",
        caution: String = "Caution"
    ) {
        self.note = note
        self.tip = tip
        self.important = important
        self.warning = warning
        self.caution = caution
    }

    public subscript(type: AdmonitionType) -> String {
        switch type {
        case .note: note
        case .tip: tip
        case .important: important
        case .warning: warning
        case .caution: caution
        }
    }

    public static let `default` = MarkdownAdmonitionTitles()
}

private struct MarkdownAdmonitionTitlesKey: EnvironmentKey {
    static let defaultValue: MarkdownAdmonitionTitles = .default
}

public extension EnvironmentValues {
    var markdownAdmonitionTitles: MarkdownAdmonitionTitles {
        get { self[MarkdownAdmonitionTitlesKey.self] }
        set { self[MarkdownAdmonitionTitlesKey.self] = newValue }
    }
}

public extension View {
    /// Renames or translates the GitHub alert titles. A title too wide for
    /// the callout ends in an ellipsis.
    func markdownAdmonitionTitles(_ titles: MarkdownAdmonitionTitles) -> some View {
        environment(\.markdownAdmonitionTitles, titles)
    }
}
