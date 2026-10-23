import UIKit

final class CodeBlockAttachmentViewProvider: HostedBlockViewProvider {
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

final class CodeBlockAttachmentView: UIView, UIScrollViewDelegate, UIContextMenuInteractionDelegate, StreamingBlockView {
    private struct Content {
        let style: CodeBlockAttachmentStyle
        let layout: CodeBlockAttachmentLayout
        let code: String
        let language: String?
        let displayLanguage: String?
        let isPending: Bool
        let attributedCode: NSAttributedString

        init(_ attachment: CodeBlockAttachment) {
            style = attachment.style
            layout = attachment.layout
            code = attachment.code
            language = attachment.language
            displayLanguage = attachment.displayLanguage
            isPending = attachment.isPending
            attributedCode = attachment.attributedCode
        }
    }

    private struct PendingFade {
        let range: NSRange
        let transition: any ViewTransition
    }

    private final class FadeOverlay: UIImageView {
        let range: NSRange

        init(image: UIImage, range: NSRange) {
            self.range = range
            super.init(image: image)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    var owner: ObjectIdentifier?
    private weak var attachment: CodeBlockAttachment?
    private var content: Content
    private let languageLabel = UILabel()
    private let copyButton = CodeBlockCopyButton(type: .system)
    private let divider = UIView()
    private let scrollView = HorizontalBlockScrollView()
    private let codeView = CodeBlockContentView()
    private var codeRect = CGRect.zero
    private var tile = CGRect.zero
    private var pendingFades: [PendingFade] = []
    private weak var enclosingScrollView: UIScrollView?
    private var scrollObservation: NSKeyValueObservation?

    static let tileMargin: CGFloat = 400

    private var overlays: [FadeOverlay] {
        scrollView.subviews.compactMap { $0 as? FadeOverlay }
    }

    init(attachment: CodeBlockAttachment) {
        self.attachment = attachment
        content = Content(attachment)
        super.init(frame: .zero)

        layer.masksToBounds = true
        addSubview(languageLabel)
        copyButton.addTarget(self, action: #selector(copyCode), for: .touchUpInside)
        addSubview(divider)

        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.delegate = self
        scrollView.addSubview(codeView)
        addSubview(scrollView)
        addSubview(copyButton)

        addInteraction(UIContextMenuInteraction(delegate: self))
        // VoiceOver reads the block through the text view's own element.
        accessibilityElementsHidden = true
        applyChrome()
        copyButton.isEnabled = !content.isPending
        codeView.replaceCode(with: content.attributedCode)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(to attachment: CodeBlockAttachment, transition: (any ViewTransition)?) {
        let previous = content
        content = Content(attachment)
        self.attachment = attachment
        let appended = Self.appendedRange(from: previous.code, to: content.code)
        if previous.style != content.style || previous.displayLanguage != content.displayLanguage {
            applyChrome()
        }
        copyButton.isEnabled = !content.isPending
        if let appended, previous.isPending == content.isPending, previous.style == content.style {
            codeView.appendCode(content.attributedCode.attributedSubstring(from: appended))
        } else {
            if appended == nil {
                discardFades()
            }
            codeView.replaceCode(with: content.attributedCode)
            for overlay in overlays {
                codeView.conceal(overlay.range)
            }
        }
        if let transition {
            fadeIn(appended ?? NSRange(location: 0, length: content.attributedCode.length), with: transition)
        }
        setNeedsLayout()
    }

    func animateContentIn(with transition: any ViewTransition) {
        guard overlays.isEmpty, pendingFades.isEmpty else { return }
        fadeIn(NSRange(location: 0, length: content.attributedCode.length), with: transition)
    }

    private static func appendedRange(from old: String, to new: String) -> NSRange? {
        guard (new as NSString).hasPrefix(old) else { return nil }
        let oldLength = (old as NSString).length
        return NSRange(location: oldLength, length: (new as NSString).length - oldLength)
    }

    private func applyChrome() {
        backgroundColor = content.style.backgroundColor
        layer.cornerRadius = content.style.cornerRadius
        layer.borderWidth = content.style.borderWidth
        languageLabel.font = content.style.headerFont
        languageLabel.textColor = content.style.headerTextColor
        languageLabel.text = content.displayLanguage
        let symbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: content.style.font.pointSize * CodeBlockAttachmentStyle.headerIconScale,
            weight: .regular
        )
        copyButton.setImage(UIImage(systemName: "doc.on.doc", withConfiguration: symbolConfiguration), for: .normal)
        copyButton.tintColor = content.style.headerTextColor
        divider.backgroundColor = content.style.dividerColor
    }

    private func fadeIn(_ range: NSRange, with transition: any ViewTransition) {
        guard range.length > 0 else { return }
        pendingFades.append(PendingFade(range: range, transition: transition))
        setNeedsLayout()
    }

    private func discardFades() {
        overlays.forEach { $0.removeFromSuperview() }
        pendingFades.removeAll()
    }

    private func placePendingFades() {
        for fade in pendingFades {
            for segment in codeView.lineSegments(of: fade.range) {
                codeView.conceal(segment.range)
                let slice = TextSlice.standalone(content.attributedCode.attributedSubstring(from: segment.range))
                let image = TextSlice.image(of: slice, size: segment.frame.size, baseline: segment.baseline, traits: traitCollection)
                let overlay = FadeOverlay(image: image, range: segment.range)
                overlay.frame = segment.frame.offsetBy(dx: codeRect.minX, dy: codeRect.minY)
                scrollView.addSubview(overlay)
                fade.transition.animate(overlay) { [weak self] in
                    guard overlay.superview != nil else { return }
                    overlay.removeFromSuperview()
                    self?.codeView.reveal(segment.range)
                }
            }
        }
        pendingFades.removeAll()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let style = content.style
        let layout = content.layout
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
        placePendingFades()
    }

    /// The border is a CGColor, which does not follow appearance changes on its own.
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsLayout()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateTile()
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
            host.copyCode(content.code, language: content.language)
        } else {
            UIPasteboard.general.string = content.code
        }
    }

    private func copyMarkdown() {
        guard let markdown = attachment?.markdownText() else { return }
        (enclosingMarkdownTextView()?.pasteboard ?? UIPasteboard.general).string = markdown
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard !content.isPending else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
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

    /// UIKit's own lift comes up blank while the text canvas re-lays out, so a leaf draws the visible part.
    private func liftPreview() -> UITargetedPreview? {
        guard let window else { return nil }
        let visible = convert(window.bounds, from: window).intersection(bounds)
        guard !visible.isEmpty else { return nil }

        let leaf = CodeBlockLiftView(panel: self, frame: visible)
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        if visible == bounds {
            parameters.visiblePath = UIBezierPath(roundedRect: leaf.bounds, cornerRadius: content.style.cornerRadius)
        }
        let target = UIPreviewTarget(container: self, center: CGPoint(x: visible.midX, y: visible.midY))
        return UITargetedPreview(view: leaf, parameters: parameters, target: target)
    }
}

final class CodeBlockCopyButton: UIButton {
    static let minimumTapTarget: CGFloat = 44

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let horizontalInset = min((bounds.width - Self.minimumTapTarget) / 2, 0)
        let verticalInset = min((bounds.height - Self.minimumTapTarget) / 2, 0)
        return bounds.insetBy(dx: horizontalInset, dy: verticalInset).contains(point)
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

/// Its own TextKit 2 stack: the text view's lazily committed layers snapshot blank on the first lift.
final class CodeBlockContentView: UIView {
    private static let stash = MarkdownAttribute.streamingOriginalColors
    private let storage = NSTextStorage()
    private let contentStorage = NSTextContentStorage()
    private let layoutManager = NSTextLayoutManager()

    init() {
        super.init(frame: .zero)
        isOpaque = false
        contentMode = .redraw

        let container = NSTextContainer(size: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.lineBreakMode = .byClipping
        layoutManager.textContainer = container
        contentStorage.textStorage = storage
        contentStorage.addTextLayoutManager(layoutManager)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var attributedCode: NSAttributedString { storage }

    func replaceCode(with code: NSAttributedString) {
        edit { $0.setAttributedString(code) }
    }

    func appendCode(_ code: NSAttributedString) {
        guard code.length > 0 else { return }
        edit { $0.append(code) }
    }

    func conceal(_ range: NSRange) {
        edit(in: range) { ColorConcealment.conceal($0, in: $1, stash: Self.stash) }
    }

    func reveal(_ range: NSRange) {
        edit(in: range) { ColorConcealment.reveal($0, in: $1, stash: Self.stash) }
    }

    func lineSegments(of range: NSRange) -> [TextLayoutHelpers.LineSegment] {
        TextLayoutHelpers.lineSegments(of: range, in: layoutManager)
    }

    private func edit(in range: NSRange, _ body: (NSTextStorage, NSRange) -> Void) {
        let clamped = NSIntersectionRange(range, NSRange(location: 0, length: storage.length))
        guard clamped.length > 0 else { return }
        edit { body($0, clamped) }
    }

    private func edit(_ body: (NSTextStorage) -> Void) {
        contentStorage.performEditingTransaction {
            storage.beginEditing()
            body(storage)
            storage.endEditing()
        }
        setNeedsDisplay()
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
