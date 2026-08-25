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
        view = TableAttachmentView(
            model: attachment.model,
            layout: attachment.layout,
            style: attachment.style
        )
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

final class TableAttachmentView: UIView {
    private let scrollView = UIScrollView()
    private let gridView: TableGridView
    private let layout: TableAttachmentLayout
    private let style: TableAttachmentStyle

    init(model: TableModel, layout: TableAttachmentLayout, style: TableAttachmentStyle) {
        self.gridView = TableGridView(model: model, layout: layout, style: style)
        self.layout = layout
        self.style = style
        super.init(frame: .zero)

        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.alwaysBounceVertical = false
        addSubview(scrollView)

        gridView.backgroundColor = .clear
        gridView.layer.cornerRadius = style.cornerRadius
        gridView.layer.masksToBounds = true
        scrollView.addSubview(gridView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        gridView.frame = CGRect(x: 0, y: 0, width: layout.totalWidth, height: layout.totalHeight)
        scrollView.contentSize = gridView.frame.size
        scrollView.isScrollEnabled = layout.totalWidth > bounds.width
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
                    let textRect = CGRect(
                        x: xOffset + style.cellPaddingHorizontal,
                        y: yOffset + style.cellPaddingVertical,
                        width: columnWidth - style.cellPaddingHorizontal * 2,
                        height: rowHeight - style.cellPaddingVertical * 2
                    )
                    row[column].attributedText.draw(
                        with: textRect,
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )
                }
                xOffset += columnWidth
            }
            yOffset += rowHeight
        }
    }

    private func rowBackground(isHeader: Bool, bodyRowIndex: Int) -> UIColor {
        if isHeader {
            return style.headerBackground
        }
        return bodyRowIndex.isMultiple(of: 2) ? style.rowEvenBackground : style.rowOddBackground
    }
}
