import UIKit

/// TextKit 2 creates and destroys providers with viewport layout, so all
/// state lives on the attachment, whose bounds override also sizes the view.
final class MathAttachmentViewProvider: NSTextAttachmentViewProvider {
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
        // Without this UIKit never installs the view.
        tracksTextAttachmentViewBounds = true
    }

    override func loadView() {
        guard let attachment = textAttachment as? MathAttachment, let panel = attachment.panel else {
            view = UIView()
            return
        }
        view = MathBlockView(attachment: attachment, panel: panel)
    }
}

/// The line-wide panel hosting a root-level display formula, inset and
/// aligned inside it and scrolling horizontally when wider than the line.
final class MathBlockView: UIView, UIScrollViewDelegate, UIContextMenuInteractionDelegate {
    let scrollView = UIScrollView()
    let formulaView = UIImageView()
    private let attachment: MathAttachment
    private let panel: MathPanelStyle
    private var didRestoreOffset = false

    init(attachment: MathAttachment, panel: MathPanelStyle) {
        self.attachment = attachment
        self.panel = panel
        super.init(frame: .zero)

        backgroundColor = panel.backgroundColor

        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.alwaysBounceVertical = false
        scrollView.delegate = self
        addSubview(scrollView)

        formulaView.image = attachment.formulaImage
        scrollView.addSubview(formulaView)

        addInteraction(UIContextMenuInteraction(delegate: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds

        let formulaSize = attachment.formulaSize
        let contentWidth = panel.contentSize(formulaSize: formulaSize).width
        let overflow = max(contentWidth - bounds.width, 0)

        formulaView.frame = CGRect(
            origin: CGPoint(
                x: panel.contentOriginX(formulaWidth: formulaSize.width, panelWidth: bounds.width),
                y: panel.padding
            ),
            size: formulaSize
        )
        scrollView.contentSize = CGSize(width: bounds.width + overflow, height: bounds.height)
        scrollView.isScrollEnabled = overflow > 0

        if !didRestoreOffset, bounds.width > 0 {
            didRestoreOffset = true
            scrollView.contentOffset.x = min(max(attachment.preservedContentOffset.x, 0), overflow)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard didRestoreOffset else { return }
        attachment.preservedContentOffset = scrollView.contentOffset
    }

    // MARK: - Copy menu

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        let attachment = self.attachment
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let copy = UIAction(
                title: "Copy",
                image: UIImage(systemName: "doc.on.doc")
            ) { _ in
                UIPasteboard.general.string = attachment.latex
            }
            let copyMarkdown = UIAction(
                title: "Copy as Markdown",
                image: UIImage(systemName: "doc.text")
            ) { _ in
                UIPasteboard.general.string = attachment.markdownText()
            }
            return UIMenu(children: [copy, copyMarkdown])
        }
    }
}
