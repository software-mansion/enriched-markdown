import SwiftUI
import UIKit

/// Drives an ``EnrichedMarkdownTextInput``: hold one in your view, pass it to the
/// input, and call its commands to focus, clear, or replace the editor's content.
///
/// Observe it for editor state — `isFocused` and `selectedRange` publish changes
/// as the user moves through the text.
@available(iOS 16.0, *)
@MainActor
public final class MarkdownEditorController: ObservableObject {
    @Published public private(set) var isFocused: Bool = false
    @Published public private(set) var selectedRange: NSRange = NSRange(location: 0, length: 0)

    let session: EditSession = EditSession()

    private weak var textView: MarkdownInputTextView?

    public init() {}

    // MARK: - Commands

    public func focus() {
        textView?.becomeFirstResponder()
    }

    public func blur() {
        textView?.resignFirstResponder()
    }

    public func clear() {
        setMarkdown("")
    }

    /// Replaces the editor's content. Like RN's `setValue`, this does not report
    /// an `onMarkdownChange` — the caller already knows what it set.
    public func setMarkdown(_ markdown: String) {
        guard let textView else { return }

        session.withPhase(.importing) {
            textView.text = markdown
            textView.updatePlaceholderVisibility()
        }
        updateSelection(textView.selectedRange)
    }

    public func getMarkdown() -> String {
        textView?.text ?? ""
    }

    // MARK: - Text view binding

    func attach(to textView: MarkdownInputTextView) {
        self.textView = textView
        session.attach(to: textView)
    }

    func detach() {
        textView = nil
        session.attach(to: nil)
        isFocused = false
    }

    func updateFocus(_ focused: Bool) {
        guard isFocused != focused else { return }
        isFocused = focused
    }

    func updateSelection(_ range: NSRange) {
        guard selectedRange != range else { return }
        selectedRange = range
    }
}
