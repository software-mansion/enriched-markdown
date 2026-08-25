import SwiftUI
import UIKit

struct MarkdownTextViewRepresentable: UIViewRepresentable {
    let attributedText: NSAttributedString
    let sourceMarkdown: String?
    let styleConfig: MarkdownStyleConfig
    let onLinkPress: ((URL) -> Void)?
    let onLinkLongPress: ((URL) -> Void)?
    let selectionMenuConfig: MarkdownSelectionMenuConfig
    let isSelectionEnabled: Bool
    let selectionColor: Color?

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
        context.coordinator.onLinkLongPress = onLinkLongPress
        context.coordinator.sourceMarkdown = sourceMarkdown
        context.coordinator.selectionMenuConfig = selectionMenuConfig
        textView.onLinkPress = onLinkPress
        textView.styleConfig = styleConfig
        textView.isSelectionEnabled = isSelectionEnabled
        textView.tintColor = selectionColor.map { UIColor($0) }
        textView.setMarkdownAttributedText(attributedText)
    }

    static func dismantleUIView(_ uiView: MarkdownTextView, coordinator: Coordinator) {
        uiView.delegate = nil
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MarkdownTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onLinkPress: ((URL) -> Void)?
        var onLinkLongPress: ((URL) -> Void)?
        var sourceMarkdown: String?
        var selectionMenuConfig = MarkdownSelectionMenuConfig()

        /// Routes a link tap; returns true when a handler consumed it.
        func handleLinkPress(_ url: URL) -> Bool {
            guard let onLinkPress else { return false }
            onLinkPress(url)
            return true
        }

        /// Routes a link long-press; returns true when a handler consumed it.
        /// Without a long-press handler, a press handler consumes every link
        /// interaction (pre-existing behavior: suppresses the system
        /// menu/preview and fires the press).
        func handleLinkLongPress(_ url: URL) -> Bool {
            if let onLinkLongPress {
                onLinkLongPress(url)
                return true
            }
            return handleLinkPress(url)
        }

        // iOS 16 (and 17+ fallback when the UITextItem methods are
        // unavailable): tap arrives as .invokeDefaultAction, long-press as
        // .presentActions or .preview.
        func textView(
            _ textView: UITextView,
            shouldInteractWith URL: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            switch interaction {
            case .invokeDefaultAction:
                return !handleLinkPress(URL)
            case .presentActions, .preview:
                return !handleLinkLongPress(URL)
            @unknown default:
                return true
            }
        }

        @available(iOS 17.0, *)
        func textView(
            _ textView: UITextView,
            primaryActionFor textItem: UITextItem,
            defaultAction: UIAction
        ) -> UIAction? {
            guard case .link(let url) = textItem.content, let onLinkPress else {
                return defaultAction
            }
            return UIAction { _ in onLinkPress(url) }
        }

        @available(iOS 17.0, *)
        func textView(
            _ textView: UITextView,
            menuConfigurationFor textItem: UITextItem,
            defaultMenu: UIMenu
        ) -> UITextItem.MenuConfiguration? {
            guard case .link(let url) = textItem.content else {
                return UITextItem.MenuConfiguration(menu: defaultMenu)
            }
            return handleLinkLongPress(url) ? nil : UITextItem.MenuConfiguration(menu: defaultMenu)
        }

        func textView(
            _ textView: UITextView,
            editMenuForTextIn range: NSRange,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            let specs = SelectionMenuItems.build(
                config: selectionMenuConfig,
                selectedRange: range,
                attributedText: textView.attributedText ?? NSAttributedString(),
                sourceMarkdown: sourceMarkdown
            )
            var actions = specs.map(Self.makeAction(for:))

            // Recent iOS versions stop suggesting Select All for non-editable text
            // views, leaving no way to grow a long-press selection to the whole
            // document; provide it ourselves when the system didn't.
            // The system shows its own item only when the command is suggested AND
            // canPerformAction allows it; recent iOS returns false there for
            // non-editable text views, hiding Select All even though the command
            // is present in suggestedActions.
            let textLength = textView.attributedText?.length ?? 0
            let systemShowsSelectAll = Self.containsSelectAll(suggestedActions)
                && textView.canPerformAction(#selector(UIResponder.selectAll(_:)), withSender: nil)
            if range.length < textLength, !systemShowsSelectAll {
                actions.append(Self.makeSelectAllAction(for: textView))
            }

            guard !actions.isEmpty else { return UIMenu(children: suggestedActions) }
            return UIMenu(children: Self.splice(actions, into: suggestedActions))
        }

        static func makeAction(for spec: MenuItemSpec) -> UIAction {
            UIAction(
                title: spec.title,
                image: UIImage(systemName: spec.systemImageName),
                identifier: UIAction.Identifier(spec.identifier)
            ) { _ in
                UIPasteboard.general.string = spec.pasteboardString
            }
        }

        static func makeSelectAllAction(for textView: UITextView) -> UIAction {
            UIAction(
                title: "Select All",
                image: UIImage(systemName: "text.badge.checkmark"),
                identifier: UIAction.Identifier("com.swmansion.enriched.markdown.selectAll")
            ) { [weak textView] _ in
                guard let textView else { return }
                Self.selectEntireDocument(in: textView)
            }
        }

        static func selectEntireDocument(in textView: UITextView) {
            textView.selectedRange = NSRange(location: 0, length: textView.attributedText?.length ?? 0)
        }

        static func containsSelectAll(_ elements: [UIMenuElement]) -> Bool {
            elements.contains { element in
                if let command = element as? UICommand, command.action == #selector(UIResponder.selectAll(_:)) {
                    return true
                }
                if let menu = element as? UIMenu {
                    return containsSelectAll(menu.children)
                }
                return false
            }
        }

        /// Inserts `actions` right after the system standard-edit submenu,
        /// keeping every system item (dropping them would remove Select All,
        /// which is the only way to grow a selection from the long-press menu
        /// of a non-editable text view). Falls back to prepending when the
        /// submenu is absent.
        static func splice(_ actions: [UIMenuElement], into suggestedActions: [UIMenuElement]) -> [UIMenuElement] {
            var result: [UIMenuElement] = []
            var foundStandardEdit = false

            for element in suggestedActions {
                result.append(element)
                if !foundStandardEdit, let menu = element as? UIMenu, menu.identifier == .standardEdit {
                    result.append(contentsOf: actions)
                    foundStandardEdit = true
                }
            }

            if !foundStandardEdit {
                result.insert(contentsOf: actions, at: 0)
            }
            return result
        }
    }
}

final class MarkdownTextView: UITextView {
    var styleConfig: MarkdownStyleConfig = .baseline() {
        didSet {
            updateDecorationStyleConfig()
        }
    }

    /// Mirrored from the representable so VoiceOver link elements can invoke
    /// the press handler via accessibilityActivate.
    var onLinkPress: ((URL) -> Void)?

    /// VoiceOver elements built from the attributed string; frames resolve
    /// lazily against TextKit 2 layout.
    private var markdownAccessibilityElements: [UIAccessibilityElement] = []

    override var accessibilityElements: [Any]? {
        get { markdownAccessibilityElements.isEmpty ? super.accessibilityElements : markdownAccessibilityElements }
        set { super.accessibilityElements = newValue }
    }

    override var isAccessibilityElement: Bool {
        get { markdownAccessibilityElements.isEmpty ? super.isAccessibilityElement : false }
        set { super.isAccessibilityElement = newValue }
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

        setupDecoration()
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
        let plain = (attributedText.string as NSString).substring(with: clamped)
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

    func setMarkdownAttributedText(_ attributedText: NSAttributedString) {
        guard !(self.attributedText?.isEqual(to: attributedText) ?? false) else { return }
        self.attributedText = attributedText
        invalidateIntrinsicContentSize()
        setDecorationNeedsDisplay()
        rebuildAccessibilityElements()
    }

    private func rebuildAccessibilityElements() {
        let specs = MarkdownAccessibilityElementBuilder.specs(for: attributedText ?? NSAttributedString())
        markdownAccessibilityElements = specs.map { spec in
            if case .link(let url) = spec.kind {
                return MarkdownLinkAccessibilityElement(textView: self, spec: spec, url: url)
            }
            return MarkdownAccessibilityElement(textView: self, spec: spec)
        }
    }

    /// Screen-coordinate frame for a character range, unioned over its
    /// TextKit 2 layout fragments.
    func accessibilityScreenFrame(for range: NSRange) -> CGRect {
        guard let textLayoutManager,
              let contentManager = textLayoutManager.textContentManager,
              let textRange = TextLayoutHelpers.textRange(range, in: contentManager) else {
            return .zero
        }

        textLayoutManager.ensureLayout(for: textRange)
        var union = CGRect.null
        textLayoutManager.enumerateTextSegments(in: textRange, type: .standard, options: []) { _, frame, _, _ in
            union = union.union(frame)
            return true
        }
        guard !union.isNull else { return .zero }

        union.origin.x += textContainerInset.left
        union.origin.y += textContainerInset.top
        return UIAccessibility.convertToScreenCoordinates(union, in: self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutDecorationView()
        setDecorationNeedsDisplay()
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
