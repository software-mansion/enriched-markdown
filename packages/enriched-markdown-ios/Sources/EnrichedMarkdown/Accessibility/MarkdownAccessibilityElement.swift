import UIKit

/// VoiceOver element for one segment of the rendered markdown. The frame is
/// resolved lazily from TextKit 2 layout on every query, so scrolling and
/// Dynamic Type changes never leave stale bounds.
class MarkdownAccessibilityElement: UIAccessibilityElement {
    private(set) weak var textView: MarkdownTextView?
    let range: NSRange
    /// For table rows: vertical slice of the attachment frame.
    private let rowSlice: (offset: CGFloat, height: CGFloat)?

    init(textView: MarkdownTextView, spec: MarkdownAccessibilityElementSpec) {
        self.textView = textView
        self.range = spec.range
        if case .tableRow(let offset, let height, _) = spec.kind {
            self.rowSlice = (offset, height)
        } else {
            self.rowSlice = nil
        }
        super.init(accessibilityContainer: textView)

        accessibilityLabel = spec.label
        accessibilityValue = spec.listAnnouncement

        switch spec.kind {
        case .text:
            accessibilityTraits = .staticText
        case .heading(let level):
            accessibilityTraits = [.staticText, .header]
            accessibilityAttributedLabel = NSAttributedString(
                string: spec.label,
                attributes: [.accessibilityTextHeadingLevel: level]
            )
        case .link:
            accessibilityTraits = .link
        case .image:
            accessibilityTraits = .image
        case .tableRow(_, _, let isHeader):
            accessibilityTraits = isHeader ? [.staticText, .header] : .staticText
        }
    }

    override var accessibilityFrame: CGRect {
        get {
            guard var frame = textView?.accessibilityScreenFrame(for: range), frame != .zero else {
                return .zero
            }
            if let rowSlice {
                frame.origin.y += rowSlice.offset
                frame.size.height = rowSlice.height
            }
            return frame
        }
        set { super.accessibilityFrame = newValue }
    }
}

final class MarkdownLinkAccessibilityElement: MarkdownAccessibilityElement {
    let url: URL

    init(textView: MarkdownTextView, spec: MarkdownAccessibilityElementSpec, url: URL) {
        self.url = url
        super.init(textView: textView, spec: spec)
    }

    override func accessibilityActivate() -> Bool {
        guard let textView, let onLinkPress = textView.onLinkPress else { return false }
        onLinkPress(url)
        return true
    }
}
