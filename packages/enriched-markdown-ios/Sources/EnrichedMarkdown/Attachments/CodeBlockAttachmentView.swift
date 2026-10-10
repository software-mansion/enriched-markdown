import UIKit

/// TextKit 2 creates and destroys providers with viewport layout, so all
/// state lives on the attachment.
final class CodeBlockAttachmentViewProvider: NSTextAttachmentViewProvider {
    override init(
        textAttachment: NSTextAttachment,
        parentView: UIView?,
        textLayoutManager: NSTextLayoutManager?,
        location: NSTextLocation
    ) {
        super.init(
            textAttachment: textAttachment,
            parentView: parentView,
            textLayoutManager: textLayoutManager,
            location: location
        )
        tracksTextAttachmentViewBounds = true
    }

    override func loadView() {
        guard let attachment = textAttachment as? CodeBlockAttachment else {
            view = UIView()
            return
        }
        let hosted = attachment.hostedView ?? CodeBlockAttachmentView(attachment: attachment)
        attachment.hostedView = hosted
        view = hosted
    }

    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: NSTextLocation,
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        guard let attachment = textAttachment as? CodeBlockAttachment else { return .zero }
        return CGRect(x: 0, y: 0, width: proposedLineFragment.width, height: attachment.layout.totalHeight)
    }
}

/// A header bar (language name, copy button) above a horizontally scrolling,
/// non-wrapping code pane.
final class CodeBlockAttachmentView: UIView, UIScrollViewDelegate, UIContextMenuInteractionDelegate {
    private weak var attachment: CodeBlockAttachment?
    private let style: CodeBlockAttachmentStyle
    private let layout: CodeBlockAttachmentLayout
    private let code: String
    private let language: String?
    private let markdown: String
    private let languageLabel = UILabel()
    private let copyButton = UIButton(type: .system)
    private let divider = UIView()
    private let scrollView = HorizontalBlockScrollView()
    private let codeView: CodeBlockContentView
    private var didRestoreOffset = false
    private var codeRect = CGRect.zero
    private var tile = CGRect.zero
    private weak var enclosingScrollView: UIScrollView?
    private var scrollObservation: NSKeyValueObservation?

    /// Points drawn beyond the visible region on each side; a long block
    /// backs a tile around what is on screen, not a bitmap its own height.
    static let tileMargin: CGFloat = 400

    init(attachment: CodeBlockAttachment) {
        self.attachment = attachment
        style = attachment.style
        layout = attachment.layout
        code = attachment.code
        language = attachment.language
        markdown = attachment.markdownText()
        self.codeView = CodeBlockContentView(attributedCode: attachment.attributedCode)
        super.init(frame: .zero)

        backgroundColor = style.backgroundColor
        layer.cornerRadius = style.cornerRadius
        layer.borderWidth = style.borderWidth
        layer.masksToBounds = true

        languageLabel.font = style.headerFont
        languageLabel.textColor = style.headerTextColor
        languageLabel.text = attachment.displayLanguage
        addSubview(languageLabel)

        let symbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: style.font.pointSize * CodeBlockAttachmentStyle.headerIconScale,
            weight: .regular
        )
        copyButton.setImage(UIImage(systemName: "doc.on.doc", withConfiguration: symbolConfiguration), for: .normal)
        copyButton.tintColor = style.headerTextColor
        copyButton.addTarget(self, action: #selector(copyCode), for: .touchUpInside)
        addSubview(copyButton)

        divider.backgroundColor = style.dividerColor
        addSubview(divider)

        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.delegate = self
        scrollView.addSubview(codeView)
        addSubview(scrollView)

        addInteraction(UIContextMenuInteraction(delegate: self))
        // The hosting text view exposes the block as one element with the
        // copy action, as it does a wrapping block.
        accessibilityElementsHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let border = ceil(style.borderWidth)
        let inset = layout.contentInset
        let headerHeight = layout.headerHeight

        layer.borderColor = style.borderColor.resolvedColor(with: traitCollection).cgColor
        scrollView.indicatorStyle = Self.isDark(style.backgroundColor.resolvedColor(with: traitCollection)) ? .white : .default

        languageLabel.sizeToFit()
        languageLabel.frame.origin = CGPoint(x: inset, y: layout.headerCenterY - languageLabel.bounds.height / 2)

        var iconWidth = copyButton.intrinsicContentSize.width
        if iconWidth <= 0 || iconWidth > headerHeight {
            iconWidth = headerHeight
        }
        let iconSlack = (headerHeight - iconWidth) / 2
        copyButton.frame = CGRect(
            x: max(bounds.width - inset - headerHeight + iconSlack, 0),
            y: max(layout.headerCenterY - headerHeight / 2, 0),
            width: headerHeight,
            height: headerHeight
        )

        divider.frame = CGRect(x: border, y: layout.dividerY, width: max(bounds.width - border * 2, 0), height: 1)

        let pane = CGRect(
            x: border,
            y: headerHeight,
            width: max(bounds.width - border * 2, 0),
            height: max(bounds.height - headerHeight - border, 0)
        )
        scrollView.frame = pane
        let horizontalPadding = max(inset - border, 0)
        let contentWidth = max(layout.codeSize.width + horizontalPadding * 2, pane.width)
        codeRect = CGRect(x: horizontalPadding, y: inset, width: layout.codeSize.width, height: pane.height - inset)
        scrollView.contentSize = CGSize(width: contentWidth, height: pane.height)
        scrollView.isScrollEnabled = contentWidth > pane.width
        updateTile()

        if !didRestoreOffset, bounds.width > 0 {
            didRestoreOffset = true
            if scrollView.isScrollEnabled {
                let maxOffset = contentWidth - pane.width
                let preserved = attachment?.preservedContentOffset.x ?? 0
                scrollView.contentOffset = CGPoint(x: min(max(preserved, 0), maxOffset), y: 0)
            }
        }
    }

    /// The border is a CGColor, which does not follow appearance changes on its own.
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsLayout()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateTile()
        guard didRestoreOffset else { return }
        attachment?.preservedContentOffset = scrollView.contentOffset
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        let found = enclosingMarkdownTextView()?.enclosingScrollView
        guard found !== enclosingScrollView else { return }
        enclosingScrollView = found
        scrollObservation = found?.observe(\.contentOffset, options: []) { [weak self] _, _ in
            self?.updateTile()
        }
    }

    private func updateTile() {
        guard !codeRect.isEmpty else { return }
        var visible = scrollView.bounds
        if let window {
            visible = visible.intersection(scrollView.convert(window.bounds, from: window))
        }
        visible = visible.intersection(codeRect)
        guard !visible.isEmpty else { return }

        let margin = Self.tileMargin
        if tile.contains(visible), tile.height <= visible.height + margin * 2, tile.width <= visible.width + margin * 2 {
            return
        }
        tile = visible.insetBy(dx: -margin, dy: -margin).intersection(codeRect)
        codeView.frame = tile
        codeView.bounds.origin = CGPoint(x: tile.minX - codeRect.minX, y: tile.minY - codeRect.minY)
        codeView.setNeedsDisplay()
    }

    private static func isDark(_ color: UIColor) -> Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var white: CGFloat = 0
        if color.getRed(&red, green: &green, blue: &blue, alpha: nil) {
            return 0.299 * red + 0.587 * green + 0.114 * blue < 0.5
        }
        return color.getWhite(&white, alpha: nil) && white < 0.5
    }

    // MARK: - Copy

    @objc private func copyCode() {
        if let host = enclosingMarkdownTextView() {
            host.copyCode(code, language: language)
        } else {
            UIPasteboard.general.string = code
        }
    }

    private func copyMarkdown() {
        (enclosingMarkdownTextView()?.pasteboard ?? UIPasteboard.general).string = markdown
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let copy = UIAction(
                title: "Copy",
                image: UIImage(systemName: "doc.on.doc")
            ) { _ in
                self?.copyCode()
            }
            let copyMarkdown = UIAction(
                title: "Copy as Markdown",
                image: UIImage(systemName: "doc.text")
            ) { _ in
                self?.copyMarkdown()
            }
            return UIMenu(children: [copy, copyMarkdown])
        }
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        liftPreview()
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        liftPreview()
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willDisplayMenuFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        alpha = 0
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        guard let animator else {
            alpha = 1
            return
        }
        animator.addAnimations { [weak self] in self?.alpha = 1 }
    }

    /// UIKit's own lift of this view comes up blank: the text view's canvas
    /// re-lays out its fragment views on every commit while the menu opens,
    /// and the lift loses its source each time. A leaf that draws the
    /// panel's visible part lifts intact, with the panel hidden underneath.
    private func liftPreview() -> UITargetedPreview? {
        guard let window else { return nil }
        let visible = convert(window.bounds, from: window).intersection(bounds)
        guard !visible.isEmpty else { return nil }

        let leaf = CodeBlockLiftView(panel: self, frame: visible)
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        if visible == bounds {
            parameters.visiblePath = UIBezierPath(roundedRect: leaf.bounds, cornerRadius: style.cornerRadius)
        }
        let target = UIPreviewTarget(container: self, center: CGPoint(x: visible.midX, y: visible.midY))
        return UITargetedPreview(view: leaf, parameters: parameters, target: target)
    }
}

final class CodeBlockLiftView: UIView {
    private weak var panel: UIView?

    init(panel: UIView, frame: CGRect) {
        self.panel = panel
        super.init(frame: frame)
        isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let panel, let context = UIGraphicsGetCurrentContext() else { return }
        context.translateBy(x: -frame.minX, y: -frame.minY)
        let alpha = panel.alpha
        panel.alpha = 1
        panel.layer.render(in: context)
        panel.alpha = alpha
    }
}

/// Draws the fragments inside the dirty rect with its own TextKit 2 stack;
/// a text view's lazily committed layers snapshot blank on the first lift.
final class CodeBlockContentView: UIView {
    private let contentStorage = NSTextContentStorage()
    private let layoutManager = NSTextLayoutManager()

    init(attributedCode: NSAttributedString) {
        super.init(frame: .zero)
        isOpaque = false
        contentMode = .redraw

        let container = NSTextContainer(size: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.lineBreakMode = .byClipping
        layoutManager.textContainer = container
        contentStorage.addTextLayoutManager(layoutManager)
        contentStorage.attributedString = attributedCode
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let start = layoutManager.textLayoutFragment(for: CGPoint(x: 0, y: rect.minY))?.rangeInElement.location
        layoutManager.enumerateTextLayoutFragments(from: start, options: [.ensuresLayout]) { fragment in
            let frame = fragment.layoutFragmentFrame
            guard frame.minY < rect.maxY else { return false }
            if frame.maxY > rect.minY {
                fragment.draw(at: frame.origin, in: context)
            }
            return true
        }
    }
}
