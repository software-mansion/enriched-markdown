import SwiftUI

/// Payload for `onTaskListItemToggle`: the item's 0-based index in document
/// order, its checked state after the toggle, and the first line of the
/// item's plain text.
public struct TaskListItemToggle: Equatable, Sendable {
    public let index: Int
    public let isChecked: Bool
    public let text: String

    public init(index: Int, isChecked: Bool, text: String) {
        self.index = index
        self.isChecked = isChecked
        self.text = text
    }
}

private struct MarkdownTaskListItemToggleHandlerKey: EnvironmentKey {
    static let defaultValue: ((TaskListItemToggle) -> Void)? = nil
}

private struct MarkdownTaskListItemToggleEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

public extension EnvironmentValues {
    var markdownTaskListItemToggleHandler: ((TaskListItemToggle) -> Void)? {
        get { self[MarkdownTaskListItemToggleHandlerKey.self] }
        set { self[MarkdownTaskListItemToggleHandlerKey.self] = newValue }
    }

    var markdownTaskListItemToggleEnabled: Bool {
        get { self[MarkdownTaskListItemToggleEnabledKey.self] }
        set { self[MarkdownTaskListItemToggleEnabledKey.self] = newValue }
    }
}

public extension View {
    /// Called after a tap on a task-list checkbox toggles the item.
    func onTaskListItemToggle(_ action: @escaping (TaskListItemToggle) -> Void) -> some View {
        environment(\.markdownTaskListItemToggleHandler, action)
    }

    /// Controls whether tapping a task-list checkbox toggles its checked
    /// state. When `false` the tap is fully inert: no visual toggle and no
    /// `onTaskListItemToggle`. Defaults to `true`. Text selection and links
    /// are unaffected.
    func markdownTaskListItemToggleEnabled(_ enabled: Bool) -> some View {
        environment(\.markdownTaskListItemToggleEnabled, enabled)
    }
}
