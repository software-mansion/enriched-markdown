import SwiftUI
import UIKit

/// An editable markdown field, styled by the same ``MarkdownTheme`` as
/// ``EnrichedMarkdownText``.
///
/// Commands and editor state live on the ``MarkdownEditorController`` you pass in;
/// changes are reported through the `on…` modifiers.
///
/// ```swift
/// EnrichedMarkdownTextInput(controller: controller, placeholder: "Write something…")
///     .onMarkdownChange { markdown = $0 }
/// ```
@available(iOS 16.0, *)
public struct EnrichedMarkdownTextInput: View {
    private let controller: MarkdownEditorController
    private let placeholder: String?
    private var events: MarkdownInputEvents = MarkdownInputEvents()

    @Environment(\.markdownThemeLayers) private var themeLayers
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(controller: MarkdownEditorController, placeholder: String? = nil) {
        self.controller = controller
        self.placeholder = placeholder
    }

    private var styleConfig: MarkdownStyleConfig {
        MarkdownStyleConfig.resolve(
            layers: themeLayers,
            colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize
        )
    }

    public var body: some View {
        MarkdownInputTextViewRepresentable(
            controller: controller,
            placeholder: placeholder,
            styleConfig: styleConfig,
            events: events
        )
    }

    // MARK: - Events

    public func onTextChange(_ action: @escaping (String) -> Void) -> Self {
        var copy = self
        copy.events.onTextChange = action
        return copy
    }

    public func onMarkdownChange(_ action: @escaping (String) -> Void) -> Self {
        var copy = self
        copy.events.onMarkdownChange = action
        return copy
    }

    public func onSelectionChange(_ action: @escaping (NSRange) -> Void) -> Self {
        var copy = self
        copy.events.onSelectionChange = action
        return copy
    }

    public func onFocusChange(_ action: @escaping (Bool) -> Void) -> Self {
        var copy = self
        copy.events.onFocusChange = action
        return copy
    }
}
