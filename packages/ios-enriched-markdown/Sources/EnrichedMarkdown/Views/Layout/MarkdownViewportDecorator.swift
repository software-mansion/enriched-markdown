import UIKit

enum MarkdownDecorationPass {
    case background
    case foreground
}

@available(iOS 16.0, *)
final class MarkdownViewportDecorator {
    private weak var backgroundView: MarkdownDecorationView?
    private weak var foregroundView: MarkdownDecorationView?
    private var config = BlockDecorationConfig(styleConfig: .baseline())

    init(backgroundView: MarkdownDecorationView, foregroundView: MarkdownDecorationView) {
        self.backgroundView = backgroundView
        self.foregroundView = foregroundView
    }

    func updateStyleConfig(_ styleConfig: MarkdownStyleConfig) {
        config = BlockDecorationConfig(styleConfig: styleConfig)
    }

    func setNeedsDisplay() {
        backgroundView?.setNeedsDisplay()
        foregroundView?.setNeedsDisplay()
    }

    func draw(in context: CGContext, textView: UITextView, pass: MarkdownDecorationPass) {
        guard let textLayoutManager = textView.textLayoutManager,
              let textContentStorage = textLayoutManager.textContentManager as? NSTextContentStorage,
              let textStorage = textContentStorage.textStorage,
              textStorage.length > 0 else {
            return
        }

        let contentManager: NSTextContentManager = textContentStorage
        let containerWidth = textView.textContainer.size.width
        let origin = CGPoint(x: 0, y: -textView.contentOffset.y)
        let visibleRange = visibleCharacterRange(
            textLayoutManager: textLayoutManager,
            contentManager: contentManager
        )
        let drawContext = BlockDrawContext(
            context: context,
            textStorage: textStorage,
            textLayoutManager: textLayoutManager,
            contentManager: contentManager,
            containerWidth: containerWidth,
            origin: origin,
            visibleCharacterRange: visibleRange,
            decorationConfig: config
        )

        switch pass {
        case .background:
            CodeBlockBackgroundDrawer.draw(in: drawContext)
            BlockquoteBorderDrawer.drawBackgrounds(in: drawContext)
        case .foreground:
            BlockquoteBorderDrawer.drawBorders(in: drawContext)
        }
    }

    private func visibleCharacterRange(
        textLayoutManager: NSTextLayoutManager,
        contentManager: NSTextContentManager
    ) -> NSRange {
        var range = NSRange(location: 0, length: 0)
        textLayoutManager.enumerateTextLayoutFragments(
            from: textLayoutManager.documentRange.location,
            options: []
        ) { fragment in
            guard let fragmentRange = TextLayoutHelpers.nsRange(fragment.rangeInElement, in: contentManager) else {
                return true
            }
            if range.length == 0 {
                range = fragmentRange
            } else {
                let end = max(NSMaxRange(range), NSMaxRange(fragmentRange))
                range = NSRange(
                    location: min(range.location, fragmentRange.location),
                    length: end - min(range.location, fragmentRange.location)
                )
            }
            return true
        }
        return range
    }
}

@available(iOS 16.0, *)
final class MarkdownDecorationView: UIView {
    weak var textView: UITextView?
    var viewportDecorator: MarkdownViewportDecorator?
    var pass: MarkdownDecorationPass = .background

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let textView,
              let viewportDecorator else {
            return
        }
        viewportDecorator.draw(in: context, textView: textView, pass: pass)
    }
}
