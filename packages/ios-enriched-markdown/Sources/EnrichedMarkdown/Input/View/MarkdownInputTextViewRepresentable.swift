import SwiftUI
import UIKit

@available(iOS 16.0, *)
struct MarkdownInputTextViewRepresentable: UIViewRepresentable {
    let controller: MarkdownEditorController
    let placeholder: String?
    let styleConfig: MarkdownStyleConfig
    let events: MarkdownInputEvents

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller, events: events)
    }

    func makeUIView(context: Context) -> MarkdownInputTextView {
        let textView = MarkdownInputTextView()
        textView.delegate = context.coordinator
        textView.placeholder = placeholder
        textView.applyBaseStyle(styleConfig)
        controller.attach(to: textView)
        return textView
    }

    func updateUIView(_ textView: MarkdownInputTextView, context: Context) {
        context.coordinator.events = events
        textView.placeholder = placeholder
        textView.applyBaseStyle(styleConfig)
    }

    static func dismantleUIView(_ textView: MarkdownInputTextView, coordinator: Coordinator) {
        textView.delegate = nil
        coordinator.controller.detach()
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        let controller: MarkdownEditorController
        var events: MarkdownInputEvents

        init(controller: MarkdownEditorController, events: MarkdownInputEvents) {
            self.controller = controller
            self.events = events
        }

        func textViewDidChange(_ textView: UITextView) {
            (textView as? MarkdownInputTextView)?.updatePlaceholderVisibility()
            controller.session.recordTextChange()

            guard !controller.session.shouldSuppressEvents else { return }
            events.onTextChange?(textView.text)
            events.onMarkdownChange?(controller.getMarkdown())
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !controller.session.shouldSuppressSelectionSideEffects else { return }
            controller.updateSelection(textView.selectedRange)
            events.onSelectionChange?(textView.selectedRange)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            controller.updateFocus(true)
            events.onFocusChange?(true)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            controller.updateFocus(false)
            events.onFocusChange?(false)
        }
    }
}
