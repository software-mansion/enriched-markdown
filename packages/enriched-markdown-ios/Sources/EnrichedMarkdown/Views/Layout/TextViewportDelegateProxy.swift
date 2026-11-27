import UIKit

/// UIKit's own delegate is the text view's canvas, which it also reaches
/// through private delegate messages; everything but the viewport is forwarded.
final class TextViewportDelegateProxy: NSObject, NSTextViewportLayoutControllerDelegate {
    private weak var original: (any NSTextViewportLayoutControllerDelegate)?

    var viewport: CGRect {
        didSet { (original as? UIView)?.setNeedsLayout() }
    }

    init(wrapping original: any NSTextViewportLayoutControllerDelegate, viewport: CGRect) {
        self.original = original
        self.viewport = viewport
    }

    func viewportBounds(for textViewportLayoutController: NSTextViewportLayoutController) -> CGRect {
        let bounded = (original?.viewportBounds(for: textViewportLayoutController) ?? .zero).intersection(viewport)
        return bounded.isNull ? .zero : bounded
    }

    func textViewportLayoutController(
        _ textViewportLayoutController: NSTextViewportLayoutController,
        configureRenderingSurfaceFor textLayoutFragment: NSTextLayoutFragment
    ) {
        original?.textViewportLayoutController(textViewportLayoutController, configureRenderingSurfaceFor: textLayoutFragment)
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || original?.responds(to: aSelector) == true
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        original
    }
}
