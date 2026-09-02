import SwiftUI

/// Payload for `onTaskListItemPress`: the item's 0-based index in document
/// order, its checked state after the toggle, and the first line of the
/// item's plain text.
public struct TaskListItemPressEvent: Equatable, Sendable {
    public let index: Int
    public let checked: Bool
    public let text: String

    public init(index: Int, checked: Bool, text: String) {
        self.index = index
        self.checked = checked
        self.text = text
    }
}

private struct MarkdownTaskListItemPressHandlerKey: EnvironmentKey {
    static let defaultValue: ((TaskListItemPressEvent) -> Void)? = nil
}

private struct MarkdownTaskListItemToggleEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

public extension EnvironmentValues {
    var markdownTaskListItemPressHandler: ((TaskListItemPressEvent) -> Void)? {
        get { self[MarkdownTaskListItemPressHandlerKey.self] }
        set { self[MarkdownTaskListItemPressHandlerKey.self] = newValue }
    }

    var markdownTaskListItemToggleEnabled: Bool {
        get { self[MarkdownTaskListItemToggleEnabledKey.self] }
        set { self[MarkdownTaskListItemToggleEnabledKey.self] = newValue }
    }
}

public extension View {
    /// Called after a tap on a task-list checkbox toggles the item.
    func onTaskListItemPress(_ action: @escaping (TaskListItemPressEvent) -> Void) -> some View {
        environment(\.markdownTaskListItemPressHandler, action)
    }

    /// Controls whether tapping a task-list checkbox toggles its checked
    /// state. When `false` the tap is fully inert: no visual toggle and no
    /// `onTaskListItemPress`. Defaults to `true`. Text selection and links
    /// are unaffected.
    func markdownTaskListItemToggleEnabled(_ enabled: Bool) -> some View {
        environment(\.markdownTaskListItemToggleEnabled, enabled)
    }
}
