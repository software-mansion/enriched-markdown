import Foundation

/// Callbacks an `EnrichedMarkdownTextInput` reports to its host.
@available(iOS 16.0, *)
struct MarkdownInputEvents {
    var onTextChange: ((String) -> Void)?
    var onMarkdownChange: ((String) -> Void)?
    var onSelectionChange: ((NSRange) -> Void)?
    var onFocusChange: ((Bool) -> Void)?
}
