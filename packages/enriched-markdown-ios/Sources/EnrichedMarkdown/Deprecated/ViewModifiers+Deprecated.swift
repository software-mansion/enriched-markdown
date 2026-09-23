import SwiftUI

// Shims for the 0.1 view modifiers and their payload types. Delete this
// file when they are removed.

public extension View {
    @available(
        *, deprecated,
        message: "Link taps go through the openURL action: .environment(\\.openURL, OpenURLAction { url in … })."
    )
    func onLinkPress(_ action: @escaping (URL) -> Void) -> some View {
        environment(\.markdownLinkPressHandler, action)
    }

    @available(*, deprecated, renamed: "onMarkdownLinkLongPress(_:)")
    func onLinkLongPress(_ action: @escaping (URL) -> Void) -> some View {
        onMarkdownLinkLongPress(action)
    }

    @available(*, deprecated, renamed: "onTaskListItemToggle(_:)")
    func onTaskListItemPress(_ action: @escaping (TaskListItemToggle) -> Void) -> some View {
        onTaskListItemToggle(action)
    }

    @available(*, deprecated, message: "Use markdownTextSelection(.enabled) or markdownTextSelection(.disabled).")
    func markdownSelectable(_ isSelectable: Bool) -> some View {
        environment(\.markdownSelectable, isSelectable)
    }
}

@available(*, deprecated, renamed: "TaskListItemToggle")
public typealias TaskListItemPressEvent = TaskListItemToggle

public extension TaskListItemToggle {
    @available(*, deprecated, renamed: "init(index:isChecked:text:)")
    init(index: Int, checked: Bool, text: String) {
        self.init(index: index, isChecked: checked, text: text)
    }

    @available(*, deprecated, renamed: "isChecked")
    var checked: Bool { isChecked }
}

public extension EnvironmentValues {
    @available(*, deprecated, renamed: "markdownTaskListItemToggleHandler")
    var markdownTaskListItemPressHandler: ((TaskListItemToggle) -> Void)? {
        get { markdownTaskListItemToggleHandler }
        set { markdownTaskListItemToggleHandler = newValue }
    }
}

@available(*, deprecated, renamed: "MarkdownSelectionMenu")
public typealias MarkdownSelectionMenuConfig = MarkdownSelectionMenu

public extension MarkdownSelectionMenu {
    @available(*, deprecated, renamed: "init(copyAsMarkdown:copyImageURL:copyAsMarkdownLabel:)")
    init(copyAsMarkdown: Bool = true, copyImageUrl: Bool, copyAsMarkdownLabel: String = "Copy as Markdown") {
        self.init(copyAsMarkdown: copyAsMarkdown, copyImageURL: copyImageUrl, copyAsMarkdownLabel: copyAsMarkdownLabel)
    }

    @available(*, deprecated, renamed: "copyImageURL")
    var copyImageUrl: Bool {
        get { copyImageURL }
        set { copyImageURL = newValue }
    }
}
