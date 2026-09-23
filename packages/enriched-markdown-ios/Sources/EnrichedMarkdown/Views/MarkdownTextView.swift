import SwiftUI
import UIKit

/// Lets the coordinator ask about handle grabs without knowing the concrete
/// text view type.
protocol SelectionHandleTouchReporting {
    var isTouchOnSelectionHandle: Bool { get }
}

final class MarkdownTextView: UITextView, SelectionHandleTouchReporting {
    var styleConfig: MarkdownStyleConfig = .baseline() {
        didSet {
            updateDecorationStyleConfig()
            // `updateUIView` assigns this on every pass, so only a real change
            // may drop the measurement — clearing it unconditionally would
            // re-measure the document every frame, which is the whole point.
            if styleConfig != oldValue {
                cachedFit = nil
                spoilerOverlays.style = styleConfig.spoiler
            }
        }
    }

    /// The exact instance last handed to `attributedText`.
    ///
    /// `UITextView.attributedText` is `@NSCopying`, so its getter cannot serve
    /// as an identity token — reading it to compare would copy the whole
    /// document. This can.
    private var renderedText: NSAttributedString?

    private struct CachedFit {
        let width: CGFloat
        let text: NSAttributedString
        let height: CGFloat
    }

    /// Measuring lays out the whole document, and SwiftUI asks for it on every
    /// update pass — and again through `intrinsicContentSize`.
    private var cachedFit: CachedFit?

    /// Mirrored from the representable so VoiceOver link elements can invoke
    /// the press handler via accessibilityActivate.
    var onLinkPress: ((URL) -> Void)?

    /// Fired with the pre-toggle state when a tap lands in a task item's
    /// checkbox margin. Nil makes checkbox taps fully inert (the
    /// `markdownTaskListItemToggleEnabled(false)` case).
    var onTaskListItemTap: ((TaskListInteraction.Hit) -> Void)?

    /// Fired with the concealed range when a tap lands on a spoiler
    /// overlay. The overlay starts fading at once; the handler owns
    /// restoring the text (see `MarkdownRenderStore.revealSpoiler`).
    var onSpoilerTap: ((NSRange) -> Void)?

    private(set) lazy var spoilerOverlays = SpoilerOverlayManager(textView: self, style: styleConfig.spoiler)

    /// Our tap recognizer must not steal touches from the text view's own
    /// recognizers (selection, links), so it observes simultaneously.
    /// UITextView is the delegate of its internal recognizers — a separate
    /// object keeps ours out of that plumbing.
    private final class SimultaneousGestureDelegate: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }

    private let tapGestureDelegate = SimultaneousGestureDelegate()

    /// VoiceOver elements and rotors, built on the first query after the
    /// text or labels change so streaming re-renders never pay for them.
    private var markdownAccessibilityElements: [MarkdownAccessibilityElement] = []
    private var markdownAccessibilityRotors: [UIAccessibilityCustomRotor] = []
    private var accessibilityTreeIsStale: Bool = true

    var accessibilityLabels: MarkdownAccessibilityLabels = .default {
        didSet {
            guard accessibilityLabels != oldValue else { return }
            accessibilityTreeIsStale = true
        }
    }

    override var accessibilityElements: [Any]? {
        get {
            let elements = accessibilityTree().elements
            return elements.isEmpty ? super.accessibilityElements : elements
        }
        set { super.accessibilityElements = newValue }
    }

    override var isAccessibilityElement: Bool {
        get { accessibilityTree().elements.isEmpty ? super.isAccessibilityElement : false }
        set { super.isAccessibilityElement = newValue }
    }

    override var accessibilityCustomRotors: [UIAccessibilityCustomRotor]? {
        get {
            let rotors = accessibilityTree().rotors
            return rotors.isEmpty ? super.accessibilityCustomRotors : rotors
        }
        set { super.accessibilityCustomRotors = newValue }
    }

    /// Gates the selection UI while keeping `isSelectable` on, so link taps
    /// keep working when selection is disabled. Selection requires first
    /// responder; link interaction does not.
    var isSelectionEnabled: Bool = true {
        didSet {
            guard isSelectionEnabled != oldValue else { return }
            if !isSelectionEnabled {
                selectedTextRange = nil
                if isFirstResponder {
                    resignFirstResponder()
                }
            }
        }
    }

    override var canBecomeFirstResponder: Bool {
        isSelectionEnabled && super.canBecomeFirstResponder
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

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapRecognizer.cancelsTouchesInView = false
        tapRecognizer.delegate = tapGestureDelegate
        addGestureRecognizer(tapRecognizer)

        setupDecoration()
    }

    /// Touch target around a selection knob: UIKit lets you grab them well
    /// outside what it draws, so this is half the 44pt minimum touch target.
    private static let selectionHandleGrabRadius: CGFloat = 22

    /// Where the most recent touch went down, in view coordinates.
    private var lastTouchDownLocation: CGPoint?

    /// True when that touch went down on one of the selection handles.
    ///
    /// The link callbacks carry no touch location of their own, and UIKit runs
    /// them before the range-adjustment gesture claims the touch, so this is
    /// what tells a handle drag apart from a press on the link underneath it.
    var isTouchOnSelectionHandle: Bool {
        guard let lastTouchDownLocation else { return false }
        return isPointOnSelectionHandle(lastTouchDownLocation)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if event?.type == .touches,
           event?.allTouches?.contains(where: { $0.phase == .began }) == true {
            lastTouchDownLocation = point
        }
        return super.hitTest(point, with: event)
    }

    /// Whether `point` (view coordinates) lands on either knob. The start knob
    /// sits above the first caret and the end knob below the last — which is
    /// why the end knob so often overlaps the following line.
    func isPointOnSelectionHandle(_ point: CGPoint) -> Bool {
        guard isFirstResponder, let range = selectedTextRange, !range.isEmpty else { return false }

        let start = caretRect(for: range.start)
        let end = caretRect(for: range.end)
        let knobs = [
            CGPoint(x: start.midX, y: start.minY),
            CGPoint(x: end.midX, y: end.maxY)
        ]
        return knobs.contains { hypot($0.x - point.x, $0.y - point.y) <= Self.selectionHandleGrabRadius }
    }

    /// The task item whose checkbox margin contains `point` (view
    /// coordinates), or nil.
    func taskListHit(at point: CGPoint) -> TaskListInteraction.Hit? {
        let containerPoint = CGPoint(
            x: point.x - textContainerInset.left,
            y: point.y - textContainerInset.top
        )
        return TaskListInteraction.hitTest(
            point: containerPoint,
            attributedText: attributedText ?? NSAttributedString(),
            textLayoutManager: textLayoutManager,
            containerWidth: bounds.width - textContainerInset.left - textContainerInset.right
        )
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        let point = recognizer.location(in: self)

        if let onSpoilerTap, let range = spoilerOverlays.concealedRange(at: point) {
            spoilerOverlays.reveal(range: range)
            onSpoilerTap(range)
            return
        }

        guard let onTaskListItemTap, let hit = taskListHit(at: point) else { return }
        onTaskListItemTap(hit)
    }

    /// Injectable so tests avoid UIPasteboard.general, which a headless test
    /// process is not authorized to access.
    var pasteboard: UIPasteboard = .general

    /// System Copy puts plain text plus a styled HTML flavor on the
    /// pasteboard, so rich-text targets keep the formatting.
    override func copy(_ sender: Any?) {
        guard let attributedText,
              attributedText.length > 0,
              selectedRange.length > 0,
              selectedRange.location != NSNotFound,
              selectedRange.location < attributedText.length
        else {
            super.copy(sender)
            return
        }

        let clamped = NSRange(
            location: selectedRange.location,
            length: min(selectedRange.length, attributedText.length - selectedRange.location)
        )
        let plain = Self.plainText(of: attributedText, in: clamped)
        let html = MarkdownHTMLGenerator.generateHTML(
            from: attributedText,
            in: clamped,
            config: styleConfig
        )
        pasteboard.items = [[
            "public.utf8-plain-text": plain,
            "public.html": html
        ]]
    }

    /// Plain text for the pasteboard, with table attachment characters
    /// replaced by the table's tab-separated content.
    static func plainText(of attributedText: NSAttributedString, in range: NSRange) -> String {
        var plain = ""
        attributedText.enumerateAttribute(.attachment, in: range) { value, runRange, _ in
            if let table = value as? TableAttachment {
                plain += table.plainText()
            } else {
                plain += (attributedText.string as NSString).substring(with: runRange)
            }
        }
        return plain
    }

    func setMarkdownAttributedText(_ attributedText: NSAttributedString) {
        // Identity first, and not as an optimization: the round trip through
        // `attributedText` does not compare equal to what was set, so the
        // guard below lets every update through and re-assigns the whole
        // document — measured at 30 re-assignments a second under a parent
        // that re-evaluates at frame rate.
        if let renderedText, renderedText === attributedText { return }
        guard !(self.attributedText?.isEqual(to: attributedText) ?? false) else { return }
        renderedText = attributedText
        cachedFit = nil
        self.attributedText = attributedText
        invalidateIntrinsicContentSize()
        setDecorationNeedsDisplay()
        accessibilityTreeIsStale = true
        // A text change alone does not schedule a layout pass, which is
        // where spoiler overlays are reconciled.
        setNeedsLayout()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        if let cachedFit, cachedFit.width == size.width, cachedFit.text === renderedText {
            return CGSize(width: size.width, height: cachedFit.height)
        }
        let fitted = super.sizeThatFits(size)
        if let renderedText {
            cachedFit = CachedFit(width: size.width, text: renderedText, height: fitted.height)
        }
        return fitted
    }

    private func accessibilityTree() -> (elements: [MarkdownAccessibilityElement], rotors: [UIAccessibilityCustomRotor]) {
        if accessibilityTreeIsStale {
            accessibilityTreeIsStale = false
            let specs = MarkdownAccessibilityElementBuilder.specs(
                for: attributedText ?? NSAttributedString(),
                labels: accessibilityLabels
            )
            markdownAccessibilityElements = specs.map { MarkdownAccessibilityElement(textView: self, spec: $0) }
            markdownAccessibilityRotors = MarkdownAccessibilityRotors.rotors(
                for: markdownAccessibilityElements,
                labels: accessibilityLabels
            )
        }
        return (markdownAccessibilityElements, markdownAccessibilityRotors)
    }

    /// Screen-coordinate frame for a character range, unioned over its
    /// TextKit 2 layout fragments.
    func accessibilityScreenFrame(for range: NSRange) -> CGRect {
        var union = CGRect.null
        TextLayoutHelpers.enumerateSegmentFrames(of: range, in: self) { frame, _ in union = union.union(frame) }
        guard !union.isNull else { return .zero }
        return UIAccessibility.convertToScreenCoordinates(union, in: self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutDecorationView()
        setDecorationNeedsDisplay()
        spoilerOverlays.update()
    }
}

private extension MarkdownTextView {
    private static var backgroundDecorationViewKey: UInt8 = 0
    private static var foregroundDecorationViewKey: UInt8 = 0
    private static var viewportDecoratorKey: UInt8 = 0

    var backgroundDecorationView: MarkdownDecorationView {
        if let view = objc_getAssociatedObject(self, &Self.backgroundDecorationViewKey) as? MarkdownDecorationView {
            return view
        }
        let view = MarkdownDecorationView()
        view.pass = .background
        objc_setAssociatedObject(self, &Self.backgroundDecorationViewKey, view, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return view
    }

    var foregroundDecorationView: MarkdownDecorationView {
        if let view = objc_getAssociatedObject(self, &Self.foregroundDecorationViewKey) as? MarkdownDecorationView {
            return view
        }
        let view = MarkdownDecorationView()
        view.pass = .foreground
        objc_setAssociatedObject(self, &Self.foregroundDecorationViewKey, view, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return view
    }

    var viewportDecorator: MarkdownViewportDecorator {
        if let decorator = objc_getAssociatedObject(self, &Self.viewportDecoratorKey) as? MarkdownViewportDecorator {
            return decorator
        }
        let decorator = MarkdownViewportDecorator(
            backgroundView: backgroundDecorationView,
            foregroundView: foregroundDecorationView
        )
        objc_setAssociatedObject(self, &Self.viewportDecoratorKey, decorator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return decorator
    }

    func setupDecoration() {
        let backgroundView = backgroundDecorationView
        let foregroundView = foregroundDecorationView
        backgroundView.textView = self
        foregroundView.textView = self
        backgroundView.viewportDecorator = viewportDecorator
        foregroundView.viewportDecorator = viewportDecorator
        viewportDecorator.updateStyleConfig(styleConfig)
        insertSubview(backgroundView, at: 0)
        addSubview(foregroundView)
    }

    func layoutDecorationView() {
        backgroundDecorationView.frame = bounds
        foregroundDecorationView.frame = bounds
    }

    func updateDecorationStyleConfig() {
        viewportDecorator.updateStyleConfig(styleConfig)
        backgroundDecorationView.setNeedsDisplay()
        foregroundDecorationView.setNeedsDisplay()
    }

    func setDecorationNeedsDisplay() {
        backgroundDecorationView.setNeedsDisplay()
        foregroundDecorationView.setNeedsDisplay()
    }
}
