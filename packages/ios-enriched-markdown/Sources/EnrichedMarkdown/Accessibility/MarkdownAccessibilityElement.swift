import UIKit

/// VoiceOver element for one segment of the rendered markdown. The frame is
/// resolved lazily from TextKit 2 layout on every query, so scrolling and
/// Dynamic Type changes never leave stale bounds.
class MarkdownAccessibilityElement: UIAccessibilityElement {
    private(set) weak var textView: MarkdownTextView?
    let range: NSRange

    init(textView: MarkdownTextView, spec: MarkdownAccessibilityElementSpec) {
        self.textView = textView
        self.range = spec.range
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
        }
    }

    override var accessibilityFrame: CGRect {
        get { textView?.accessibilityScreenFrame(for: range) ?? .zero }
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
