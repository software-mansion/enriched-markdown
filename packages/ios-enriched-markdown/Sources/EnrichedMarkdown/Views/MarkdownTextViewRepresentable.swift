import SwiftUI
import UIKit

struct MarkdownTextViewRepresentable: UIViewRepresentable {
    let attributedText: NSAttributedString
    let styleConfig: MarkdownStyleConfig
    let onLinkPress: ((URL) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MarkdownTextView {
        let textView = MarkdownTextView()
        textView.delegate = context.coordinator
        textView.styleConfig = styleConfig
        return textView
    }

    func updateUIView(_ textView: MarkdownTextView, context: Context) {
        context.coordinator.onLinkPress = onLinkPress
        textView.styleConfig = styleConfig
        textView.setMarkdownAttributedText(attributedText)
    }

    static func dismantleUIView(_ uiView: MarkdownTextView, coordinator: Coordinator) {
        uiView.delegate = nil
    }

    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MarkdownTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onLinkPress: ((URL) -> Void)?

        func textView(
            _ textView: UITextView,
            shouldInteractWith URL: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            if let onLinkPress {
                onLinkPress(URL)
                return false
            }
            return true
        }
    }
}

final class MarkdownTextView: UITextView {
    var styleConfig: MarkdownStyleConfig = .baseline() {
        didSet {
            if #available(iOS 16.0, *) {
                updateDecorationStyleConfig()
            }
        }
    }

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
        isSelectable = true
        isScrollEnabled = false
        backgroundColor = .clear
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        dataDetectorTypes = []
        linkTextAttributes = [:]
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        if #available(iOS 16.0, *) {
            setupDecoration()
        }
    }

    func setMarkdownAttributedText(_ attributedText: NSAttributedString) {
        guard !(self.attributedText?.isEqual(to: attributedText) ?? false) else { return }
        self.attributedText = attributedText
        invalidateIntrinsicContentSize()
        if #available(iOS 16.0, *) {
            setDecorationNeedsDisplay()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if #available(iOS 16.0, *) {
            layoutDecorationView()
            setDecorationNeedsDisplay()
        }
    }
}

@available(iOS 16.0, *)
private extension MarkdownTextView {
    private static var decorationViewKey: UInt8 = 0
    private static var viewportDecoratorKey: UInt8 = 0

    var decorationView: MarkdownDecorationView {
        if let view = objc_getAssociatedObject(self, &Self.decorationViewKey) as? MarkdownDecorationView {
            return view
        }
        let view = MarkdownDecorationView()
        objc_setAssociatedObject(self, &Self.decorationViewKey, view, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return view
    }

    var viewportDecorator: MarkdownViewportDecorator {
        if let decorator = objc_getAssociatedObject(self, &Self.viewportDecoratorKey) as? MarkdownViewportDecorator {
            return decorator
        }
        let decorator = MarkdownViewportDecorator(decorationView: decorationView)
        objc_setAssociatedObject(self, &Self.viewportDecoratorKey, decorator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return decorator
    }

    func setupDecoration() {
        decorationView.textView = self
        decorationView.viewportDecorator = viewportDecorator
        viewportDecorator.updateStyleConfig(styleConfig)
        insertSubview(decorationView, at: 0)
    }

    func layoutDecorationView() {
        decorationView.frame = bounds
    }

    func updateDecorationStyleConfig() {
        viewportDecorator.updateStyleConfig(styleConfig)
        decorationView.setNeedsDisplay()
    }

    func setDecorationNeedsDisplay() {
        decorationView.setNeedsDisplay()
    }
}
