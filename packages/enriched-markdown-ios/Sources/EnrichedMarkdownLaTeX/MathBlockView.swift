import EnrichedMarkdown
import UIKit

/// The line-wide panel hosting a root-level display formula, inset and
/// aligned inside it and scrolling horizontally when wider than the line.
final class MathBlockView: UIView, UIContextMenuInteractionDelegate, HostedBlockView {
    var owner: ObjectIdentifier?
    let scrollView = HorizontalBlockScrollView()
    let formulaView = UIImageView()
    private weak var attachment: MathAttachment?
    private var formulaSize: CGSize
    private var panel: MathPanelStyle

    init(attachment: MathAttachment, panel: MathPanelStyle) {
        self.attachment = attachment
        formulaSize = attachment.formulaSize
        self.panel = panel
        super.init(frame: .zero)

        backgroundColor = panel.backgroundColor

        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.alwaysBounceVertical = false
        addSubview(scrollView)

        formulaView.image = attachment.formulaImage
        scrollView.addSubview(formulaView)

        addInteraction(UIContextMenuInteraction(delegate: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(to attachment: MathAttachment) {
        self.attachment = attachment
        formulaSize = attachment.formulaSize
        if let panel = attachment.panel {
            self.panel = panel
        }
        backgroundColor = panel.backgroundColor
        formulaView.image = attachment.formulaImage
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds

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
    }

    // MARK: - Copy menu

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let attachment else { return nil }
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
