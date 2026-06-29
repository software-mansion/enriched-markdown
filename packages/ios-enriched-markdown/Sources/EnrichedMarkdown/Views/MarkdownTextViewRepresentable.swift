import SwiftUI
import UIKit

struct MarkdownTextViewRepresentable: UIViewRepresentable {
    let attributedText: NSAttributedString

    func makeUIView(context: Context) -> MarkdownTextView {
        MarkdownTextView()
    }

    func updateUIView(_ textView: MarkdownTextView, context: Context) {
        textView.setMarkdownAttributedText(attributedText)
    }

    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MarkdownTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }
}

final class MarkdownTextView: UITextView {
    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : UIView.noIntrinsicMetric
        guard width != UIView.noIntrinsicMetric else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
        let size = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }

    init() {
        super.init(frame: .zero, textContainer: nil)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        isEditable = false
        isScrollEnabled = false
        backgroundColor = .clear
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    func setMarkdownAttributedText(_ attributedText: NSAttributedString) {
        guard !(self.attributedText?.isEqual(to: attributedText) ?? false) else { return }
        self.attributedText = attributedText
        invalidateIntrinsicContentSize()
    }
}
