import UIKit

/// TextKit 2 creates and destroys providers with viewport layout, so all
/// state lives on the attachment.
final class TableAttachmentViewProvider: NSTextAttachmentViewProvider {
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
        guard let attachment = textAttachment as? TableAttachment else {
            view = UIView()
            return
        }
        view = TableAttachmentView(attachment: attachment)
    }

    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: NSTextLocation,
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        guard let attachment = textAttachment as? TableAttachment else { return .zero }
        return CGRect(x: 0, y: 0, width: proposedLineFragment.width, height: attachment.layout.totalHeight)
    }
}

final class TableAttachmentView: UIView, UIScrollViewDelegate, UIContextMenuInteractionDelegate {
    private let scrollView = UIScrollView()
    private let gridView: TableGridView
    private let attachment: TableAttachment
    private var didRestoreOffset = false

    init(attachment: TableAttachment) {
        self.attachment = attachment
        self.gridView = TableGridView(
            model: attachment.model,
            layout: attachment.layout,
            style: attachment.style
        )
        super.init(frame: .zero)

        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.alwaysBounceVertical = false
        scrollView.delegate = self
        addSubview(scrollView)

        gridView.backgroundColor = .clear
        gridView.layer.cornerRadius = attachment.style.cornerRadius
        gridView.layer.masksToBounds = true
        scrollView.addSubview(gridView)

        gridView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        )
        gridView.addInteraction(UIContextMenuInteraction(delegate: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let layout = attachment.layout
        scrollView.frame = bounds

        let fits = layout.totalWidth <= bounds.width
        let alignOffset: CGFloat
        if fits {
            switch attachment.style.align {
            case .leading: alignOffset = 0
            case .center: alignOffset = (bounds.width - layout.totalWidth) / 2
            case .trailing: alignOffset = bounds.width - layout.totalWidth
            }
        } else {
            alignOffset = 0
        }

        gridView.frame = CGRect(
            x: alignOffset,
            y: 0,
            width: layout.totalWidth,
            height: layout.totalHeight
        )
        scrollView.contentSize = CGSize(
            width: max(layout.totalWidth, bounds.width),
            height: layout.totalHeight
        )
        scrollView.isScrollEnabled = !fits

        if !didRestoreOffset, bounds.width > 0 {
            didRestoreOffset = true
            if !fits {
                let maxOffset = layout.totalWidth - bounds.width
                let restored = min(max(attachment.preservedContentOffset.x, 0), maxOffset)
                scrollView.contentOffset = CGPoint(x: restored, y: 0)
            }
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard didRestoreOffset else { return }
        attachment.preservedContentOffset = scrollView.contentOffset
    }

    // MARK: - Link taps

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let url = gridView.linkURL(at: recognizer.location(in: gridView)) else { return }
        if let onLinkPress = hostTextView()?.onLinkPress {
            onLinkPress(url)
        } else {
            UIApplication.shared.open(url)
        }
    }

    private func hostTextView() -> MarkdownTextView? {
        var view: UIView? = superview
        while let current = view {
            if let textView = current as? MarkdownTextView { return textView }
            view = current.superview
        }
        return nil
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
                UIPasteboard.general.string = attachment.plainText()
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

/// Draws the whole grid in one pass; cell rects overlap by one border width
/// so adjacent strokes coincide.
final class TableGridView: UIView {
    private let model: TableModel
    private let layout: TableAttachmentLayout
    private let style: TableAttachmentStyle

    init(model: TableModel, layout: TableAttachmentLayout, style: TableAttachmentStyle) {
        self.model = model
        self.layout = layout
        self.style = style
        super.init(frame: .zero)
        isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        var yOffset: CGFloat = 0
        var bodyRowIndex = 0
        for (rowIndex, row) in model.rows.enumerated() {
            let rowHeight = layout.rowHeights[rowIndex]
            let isHeaderRow = row.first?.isHeader ?? false
            let background = rowBackground(isHeader: isHeaderRow, bodyRowIndex: bodyRowIndex)
            if !isHeaderRow {
                bodyRowIndex += 1
            }

            var xOffset: CGFloat = 0
            for column in 0..<model.columnCount {
                let columnWidth = layout.columnWidths[column]
                let cellRect = CGRect(
                    x: xOffset,
                    y: yOffset,
                    width: columnWidth + style.borderWidth,
                    height: rowHeight + style.borderWidth
                )

                context.setFillColor(background.cgColor)
                context.fill(cellRect)
                context.setStrokeColor(style.borderColor.cgColor)
                context.setLineWidth(style.borderWidth)
                context.stroke(cellRect)

                if column < row.count {
                    row[column].attributedText.draw(
                        with: textRect(column: column, xOffset: xOffset, yOffset: yOffset, rowHeight: rowHeight),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )
                }
                xOffset += columnWidth
            }
            yOffset += rowHeight
        }
    }

    /// Resolves a tap on the grid to a `.link` attribute in the tapped
    /// cell, via a throwaway TextKit stack matching the drawing geometry.
    func linkURL(at point: CGPoint) -> URL? {
        guard let cell = cell(at: point) else { return nil }
        let local = CGPoint(x: point.x - cell.textRect.minX, y: point.y - cell.textRect.minY)
        guard local.x >= 0, local.y >= 0,
              local.x <= cell.textRect.width, local.y <= cell.textRect.height else {
            return nil
        }

        let storage = NSTextStorage(attributedString: cell.text)
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: cell.textRect.size)
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)

        let glyphIndex = layoutManager.glyphIndex(for: local, in: container)
        guard glyphIndex < layoutManager.numberOfGlyphs else { return nil }
        let glyphRect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            in: container
        )
        guard glyphRect.insetBy(dx: -4, dy: -4).contains(local) else { return nil }

        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        guard characterIndex < cell.text.length else { return nil }
        let value = cell.text.attribute(.link, at: characterIndex, effectiveRange: nil)
        if let url = value as? URL { return url }
        if let string = value as? String { return URL(string: string) }
        return nil
    }

    private func cell(at point: CGPoint) -> (text: NSAttributedString, textRect: CGRect)? {
        var yOffset: CGFloat = 0
        for (rowIndex, row) in model.rows.enumerated() {
            let rowHeight = layout.rowHeights[rowIndex]
            if point.y >= yOffset, point.y < yOffset + rowHeight {
                var xOffset: CGFloat = 0
                for column in 0..<model.columnCount {
                    let columnWidth = layout.columnWidths[column]
                    if point.x >= xOffset, point.x < xOffset + columnWidth {
                        guard column < row.count else { return nil }
                        return (
                            row[column].attributedText,
                            textRect(column: column, xOffset: xOffset, yOffset: yOffset, rowHeight: rowHeight)
                        )
                    }
                    xOffset += columnWidth
                }
                return nil
            }
            yOffset += rowHeight
        }
        return nil
    }

    private func textRect(
        column: Int,
        xOffset: CGFloat,
        yOffset: CGFloat,
        rowHeight: CGFloat
    ) -> CGRect {
        CGRect(
            x: xOffset + style.cellPaddingHorizontal,
            y: yOffset + style.cellPaddingVertical,
            width: layout.columnWidths[column] - style.cellPaddingHorizontal * 2,
            height: rowHeight - style.cellPaddingVertical * 2
        )
    }

    private func rowBackground(isHeader: Bool, bodyRowIndex: Int) -> UIColor {
        if isHeader {
            return style.headerBackground
        }
        return bodyRowIndex.isMultiple(of: 2) ? style.rowEvenBackground : style.rowOddBackground
    }
}
