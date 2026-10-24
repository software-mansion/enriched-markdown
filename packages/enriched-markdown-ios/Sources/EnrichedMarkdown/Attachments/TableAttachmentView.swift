import UIKit

final class TableAttachmentViewProvider: HostedBlockViewProvider {
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

final class TableAttachmentView: UIView, UIContextMenuInteractionDelegate, StreamingBlockView {
    private struct PendingFade {
        let rows: [Int]
        let transition: any ViewTransition
    }

    private final class FadeOverlay: UIImageView {
        let row: Int

        init(image: UIImage, row: Int) {
            self.row = row
            super.init(image: image)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    var owner: ObjectIdentifier?
    private let scrollView = HorizontalBlockScrollView()
    private let gridView: TableGridView
    private weak var attachment: TableAttachment?
    private var pendingFades: [PendingFade] = []

    private var overlays: [FadeOverlay] {
        scrollView.subviews.compactMap { $0 as? FadeOverlay }
    }

    init(attachment: TableAttachment) {
        self.attachment = attachment
        gridView = TableGridView(model: attachment.model, layout: attachment.layout, style: attachment.style)
        super.init(frame: .zero)

        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.alwaysBounceVertical = false
        addSubview(scrollView)
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

    func update(to attachment: TableAttachment, transition: (any ViewTransition)?) {
        let previousRows = gridView.model.rows.count
        let extends = Self.rows(of: attachment.model, extend: gridView.model)
        let layoutChanged = attachment.layout != gridView.layout
        self.attachment = attachment
        if !extends {
            discardFades()
        }
        gridView.update(model: attachment.model, layout: attachment.layout, style: attachment.style)
        if layoutChanged {
            for overlay in overlays {
                overlay.image = gridView.textImage(ofRow: overlay.row, traits: traitCollection)
                overlay.bounds.size = gridView.rowRect(overlay.row).size
            }
        }
        if let transition {
            fadeIn(rows: Array((extends ? previousRows : 0)..<attachment.model.rows.count), with: transition)
        }
        setNeedsLayout()
    }

    func animateContentIn(with transition: any ViewTransition) {
        guard overlays.isEmpty, pendingFades.isEmpty else { return }
        fadeIn(rows: Array(gridView.model.rows.indices), with: transition)
    }

    private static func rows(of new: TableModel, extend old: TableModel) -> Bool {
        new.rows.count >= old.rows.count && zip(old.rows, new.rows).allSatisfy { old, new in
            old.count == new.count && zip(old, new).allSatisfy { $0.plainText == $1.plainText }
        }
    }

    private func fadeIn(rows: [Int], with transition: any ViewTransition) {
        guard !rows.isEmpty else { return }
        gridView.concealedRows.formUnion(rows)
        gridView.setNeedsDisplay()
        pendingFades.append(PendingFade(rows: rows, transition: transition))
        setNeedsLayout()
    }

    private func discardFades() {
        overlays.forEach { $0.removeFromSuperview() }
        pendingFades.removeAll()
        gridView.concealedRows.removeAll()
        gridView.setNeedsDisplay()
    }

    private func placePendingFades() {
        for fade in pendingFades {
            for row in fade.rows {
                let overlay = FadeOverlay(image: gridView.textImage(ofRow: row, traits: traitCollection), row: row)
                overlay.frame = gridView.convert(gridView.rowRect(row), to: scrollView)
                scrollView.addSubview(overlay)
                fade.transition.animate(overlay) { [weak self] in
                    guard overlay.superview != nil else { return }
                    overlay.removeFromSuperview()
                    self?.gridView.concealedRows.remove(row)
                    self?.gridView.setNeedsDisplay()
                }
            }
        }
        pendingFades.removeAll()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds

        let layout = gridView.layout
        let fits = layout.totalWidth <= bounds.width
        let alignOffset: CGFloat
        if fits {
            switch gridView.style.alignment {
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

        for overlay in overlays {
            let rect = gridView.convert(gridView.rowRect(overlay.row), to: scrollView)
            overlay.center = CGPoint(x: rect.midX, y: rect.midY)
        }
        placePendingFades()
    }

    // MARK: - Link taps

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let url = gridView.linkURL(at: recognizer.location(in: gridView)) else { return }
        openLink(url)
    }

    /// Routes a tapped cell link through the host text view's handler,
    /// which the SwiftUI view sets to its `onLinkPress` or `openURL`; a
    /// text view outside SwiftUI with no handler opens the URL directly.
    func openLink(_ url: URL) {
        if let onLinkPress = enclosingMarkdownTextView()?.onLinkPress {
            onLinkPress(url)
        } else {
            UIApplication.shared.open(url)
        }
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
    private(set) var model: TableModel
    private(set) var layout: TableAttachmentLayout
    private(set) var style: TableAttachmentStyle
    var concealedRows: Set<Int> = []

    init(model: TableModel, layout: TableAttachmentLayout, style: TableAttachmentStyle) {
        self.model = model
        self.layout = layout
        self.style = style
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
        layer.cornerRadius = style.cornerRadius
        layer.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(model: TableModel, layout: TableAttachmentLayout, style: TableAttachmentStyle) {
        guard model != self.model || layout != self.layout || style != self.style else { return }
        self.model = model
        self.layout = layout
        self.style = style
        layer.cornerRadius = style.cornerRadius
        setNeedsDisplay()
    }

    func rowRect(_ row: Int) -> CGRect {
        CGRect(
            x: 0,
            y: layout.rowHeights[..<row].reduce(0, +),
            width: layout.totalWidth,
            height: layout.rowHeights[row]
        )
    }

    func textImage(ofRow row: Int, traits: UITraitCollection) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: rowRect(row).size, format: format).image { _ in
            traits.performAsCurrent {
                drawText(ofRow: row, yOffset: 0)
            }
        }
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
                xOffset += columnWidth
            }
            if !concealedRows.contains(rowIndex) {
                drawText(ofRow: rowIndex, yOffset: yOffset)
            }
            yOffset += rowHeight
        }
    }

    private func drawText(ofRow rowIndex: Int, yOffset: CGFloat) {
        let row = model.rows[rowIndex]
        let rowHeight = layout.rowHeights[rowIndex]
        var xOffset: CGFloat = 0
        for column in 0..<min(row.count, model.columnCount) {
            row[column].attributedText.draw(
                with: textRect(column: column, xOffset: xOffset, yOffset: yOffset, rowHeight: rowHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            xOffset += layout.columnWidths[column]
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
