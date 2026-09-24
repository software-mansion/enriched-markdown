import UIKit

enum MarkdownDecorationPass {
    case background
    case foreground
}

final class MarkdownViewportDecorator {
    private weak var backgroundView: MarkdownDecorationView?
    private weak var foregroundView: MarkdownDecorationView?
    private var config = BlockDecorationConfig(styleConfig: .baseline())

    init(backgroundView: MarkdownDecorationView, foregroundView: MarkdownDecorationView) {
        self.backgroundView = backgroundView
        self.foregroundView = foregroundView
    }

    func updateStyleConfig(_ styleConfig: MarkdownStyleConfiguration) {
        config = BlockDecorationConfig(styleConfig: styleConfig)
    }

    func setNeedsDisplay() {
        backgroundView?.setNeedsDisplay()
        foregroundView?.setNeedsDisplay()
    }

    /// Draws one pass for `tile`, the part of the text view the receiving
    /// decoration view covers, in that view's coordinates.
    func draw(in context: CGContext, textView: UITextView, tile: CGRect, pass: MarkdownDecorationPass) {
        guard let textLayoutManager = textView.textLayoutManager else { return }

        // Container coordinates: the content sits at minus the scroll offset.
        let containerTile = tile.offsetBy(dx: 0, dy: textView.contentOffset.y)
        let drawContext = DecorationDrawContext(
            context: context,
            paragraphs: ParagraphLayoutWalker.paragraphs(in: textLayoutManager, intersecting: containerTile),
            textLayoutManager: textLayoutManager,
            containerWidth: textView.textContainer.size.width,
            origin: CGPoint(x: -containerTile.minX, y: -containerTile.minY),
            decorationConfig: config
        )

        switch pass {
        case .background:
            CodeBlockBackgroundDrawer.draw(in: drawContext)
            BlockquoteBorderDrawer.drawBackgrounds(in: drawContext)
        case .foreground:
            BlockquoteBorderDrawer.drawBorders(in: drawContext)
            ParagraphMarkerDrawer.draw(in: drawContext)
        }
    }
}

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
        viewportDecorator.draw(in: context, textView: textView, tile: frame, pass: pass)
    }
}
