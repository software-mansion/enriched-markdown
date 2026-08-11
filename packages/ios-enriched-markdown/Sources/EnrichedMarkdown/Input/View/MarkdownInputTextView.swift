import UIKit

@available(iOS 16.0, *)
final class MarkdownInputTextView: UITextView {
    var placeholder: String? {
        didSet {
            placeholderLabel.text = placeholder
            updatePlaceholderVisibility()
            setNeedsLayout()
        }
    }

    private let placeholderLabel: UILabel = UILabel()

    init() {
        super.init(frame: .zero, textContainer: nil)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        isEditable = true
        isSelectable = true
        isScrollEnabled = true
        backgroundColor = .clear
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        dataDetectorTypes = []

        placeholderLabel.numberOfLines = 0
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.isUserInteractionEnabled = false
        addSubview(placeholderLabel)
    }

    /// Applies the resolved theme's paragraph style as the editor's base style —
    /// the appearance of text carrying no inline formatting.
    ///
    /// Assigning `font` or `textColor` re-stamps that attribute over the whole
    /// text storage, so only a genuine change may go through: this runs on every
    /// SwiftUI update pass, including one per keystroke.
    func applyBaseStyle(_ config: MarkdownStyleConfig) {
        let baseFont = config.paragraph.font ?? UIFont.preferredFont(forTextStyle: .body)
        let baseColor = config.paragraph.foregroundColor ?? .label

        if placeholderLabel.font != baseFont {
            placeholderLabel.font = baseFont
            setNeedsLayout()
        }

        guard font != baseFont || textColor != baseColor else { return }
        font = baseFont
        textColor = baseColor
    }

    func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = placeholder == nil || !text.isEmpty
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutPlaceholder()
    }

    private func layoutPlaceholder() {
        let padding = textContainer.lineFragmentPadding
        let width = bounds.width - textContainerInset.left - textContainerInset.right - padding * 2
        guard width > 0 else { return }

        let fittingSize = placeholderLabel.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        placeholderLabel.frame = CGRect(
            x: textContainerInset.left + padding,
            y: textContainerInset.top,
            width: width,
            height: fittingSize.height
        )
    }
}
