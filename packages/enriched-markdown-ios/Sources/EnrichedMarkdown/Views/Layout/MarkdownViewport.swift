import UIKit

/// A tile around the visible region of the enclosing scroll view, kept until
/// the region leaves it or the tile outgrows its budget; the whole document
/// outside a scroll view. It is TextKit's viewport and the decoration views'
/// frame: laid out in full, a long document costs hundreds of megabytes.
final class MarkdownViewport {
    /// Points kept beyond the visible region on each side, so ordinary
    /// scrolling reuses a tile and a re-tile happens once per margin.
    static let margin: CGFloat = 600

    private weak var textView: UITextView?
    private let decorator: MarkdownViewportDecorator
    private var rect: CGRect = .zero

    /// Whose visible region the tile follows; nil covers the whole document.
    private(set) weak var enclosingScrollView: UIScrollView?
    private var scrollObservation: NSKeyValueObservation?
    private var layoutDelegate: TextViewportDelegateProxy?

    init(textView: UITextView, decorator: MarkdownViewportDecorator) {
        self.textView = textView
        self.decorator = decorator
    }

    /// UIKit reports only some moves to a view, so each report looks the
    /// scroll view up again: a new window reaches every descendant, a move
    /// within one window only the moved view, and an ancestor moving into or
    /// out of a scroll view reaches the text view as a trait change that lays
    /// it out. An ancestor moving from one scroll view straight into another
    /// reaches none of them.
    func track() {
        guard let textView else { return }
        let found = textView.firstAncestor(of: UIScrollView.self)
        if found !== enclosingScrollView {
            enclosingScrollView = found
            scrollObservation = found?.observe(\.contentOffset, options: []) { [weak self] _, _ in
                self?.update()
            }
        }
        bindTextLayout(of: textView)
        update()
    }

    func update() {
        guard let textView else { return }
        let fitted = fit(in: textView)
        guard fitted != rect else { return }
        rect = fitted
        decorator.setTile(fitted)
        layoutDelegate?.viewport = containerRect(in: textView)
    }

    private func fit(in textView: UITextView) -> CGRect {
        let bounds = textView.bounds
        guard let scrollView = enclosingScrollView else { return bounds }
        let visible = textView.convert(scrollView.bounds, from: scrollView).intersection(bounds)
        // Off screen, or not laid out yet: nothing to show until that changes.
        guard !visible.isEmpty else { return rect }

        let margin = Self.margin
        if rect.contains(visible), rect.height <= visible.height + margin * 2 {
            return rect.intersection(bounds)
        }
        return visible.insetBy(dx: 0, dy: -margin).integral.intersection(bounds)
    }

    private func containerRect(in textView: UITextView) -> CGRect {
        let inset = textView.textContainerInset
        return rect.offsetBy(dx: -inset.left, dy: -inset.top)
    }

    private func bindTextLayout(of textView: UITextView) {
        guard let controller = textView.textLayoutManager?.textViewportLayoutController else { return }
        if let layoutDelegate, controller.delegate === layoutDelegate { return }
        guard let delegate = controller.delegate else { return }
        let proxy = TextViewportDelegateProxy(wrapping: delegate, viewport: containerRect(in: textView))
        controller.delegate = proxy
        layoutDelegate = proxy
    }
}
