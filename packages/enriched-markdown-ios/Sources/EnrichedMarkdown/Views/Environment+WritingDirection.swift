import SwiftUI

/// How each paragraph's base writing direction is resolved. Mirrors the
/// React Native package's `writingDirection` prop.
public enum MarkdownWritingDirection: CaseIterable, Equatable, Sendable {
    /// Each paragraph follows its first strong directional character;
    /// paragraphs without one (digits, punctuation) follow the SwiftUI
    /// layout direction. The default, matching Android.
    case firstStrong
    /// Leaves direction to TextKit, as the React Native prop's `auto` does.
    /// List markers, checkboxes, blockquote bars, and paragraphs with no
    /// strong character then follow the app's interface direction.
    case natural
    /// Forces every paragraph left-to-right.
    case leftToRight
    /// Forces every paragraph right-to-left.
    case rightToLeft
}

private struct MarkdownWritingDirectionKey: EnvironmentKey {
    static let defaultValue: MarkdownWritingDirection = .firstStrong
}

public extension EnvironmentValues {
    var markdownWritingDirection: MarkdownWritingDirection {
        get { self[MarkdownWritingDirectionKey.self] }
        set { self[MarkdownWritingDirectionKey.self] = newValue }
    }
}

public extension View {
    /// Sets how paragraphs resolve their base writing direction, which also
    /// places list markers, checkboxes, and blockquote bars on the
    /// paragraph's side. Defaults to `.firstStrong`. Code blocks always
    /// render left-to-right.
    func markdownWritingDirection(_ direction: MarkdownWritingDirection) -> some View {
        environment(\.markdownWritingDirection, direction)
    }
}
