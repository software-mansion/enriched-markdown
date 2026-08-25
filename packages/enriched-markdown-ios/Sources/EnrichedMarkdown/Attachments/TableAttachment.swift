import UIKit
import UniformTypeIdentifiers

struct TableCellModel: Equatable {
    let attributedText: NSAttributedString
    let isHeader: Bool
}

struct TableModel: Equatable {
    let rows: [[TableCellModel]]
    let columnCount: Int
}

/// RN-parity defaults; theme plumbing comes with the production table work.
struct TableAttachmentStyle {
    static let `default` = TableAttachmentStyle()

    var textColor = UIColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1)
    var headerTextColor = UIColor(red: 0.07, green: 0.09, blue: 0.15, alpha: 1)
    var headerBackground = UIColor(red: 0.95, green: 0.96, blue: 0.96, alpha: 1)
    var rowEvenBackground = UIColor.white
    var rowOddBackground = UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1)
    var borderColor = UIColor(red: 0.90, green: 0.91, blue: 0.92, alpha: 1)
    var borderWidth: CGFloat = 1
    var cornerRadius: CGFloat = 6
    var fontSize: CGFloat = 14
    var cellPaddingHorizontal: CGFloat = 12
    var cellPaddingVertical: CGFloat = 8
    var marginBottom: CGFloat = 16

    static let minColumnWidth: CGFloat = 60
    static let maxColumnWidth: CGFloat = 300
}

/// Two-pass intrinsic column sizing ported from the React Native package.
/// Totals include one border width because adjacent cell strokes overlap.
struct TableAttachmentLayout: Equatable {
    let columnWidths: [CGFloat]
    let rowHeights: [CGFloat]
    let totalWidth: CGFloat
    let totalHeight: CGFloat

    static func compute(model: TableModel, style: TableAttachmentStyle) -> TableAttachmentLayout {
        let horizontalPadding = style.cellPaddingHorizontal * 2
        let verticalPadding = style.cellPaddingVertical * 2
        var columnWidths = [CGFloat](repeating: 0, count: model.columnCount)

        for row in model.rows {
            for (column, cell) in row.enumerated() {
                let bounding = cell.attributedText.boundingRect(
                    with: CGSize(width: Self.maxColumnWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                let width = min(
                    max(ceil(bounding.width) + horizontalPadding, Self.minColumnWidth),
                    Self.maxColumnWidth + horizontalPadding
                )
                columnWidths[column] = max(columnWidths[column], width)
            }
        }

        var rowHeights: [CGFloat] = []
        for row in model.rows {
            var rowHeight: CGFloat = 0
            for (column, cell) in row.enumerated() {
                let availableWidth = columnWidths[column] - horizontalPadding
                let bounding = cell.attributedText.boundingRect(
                    with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                rowHeight = max(rowHeight, ceil(bounding.height) + verticalPadding)
            }
            rowHeights.append(rowHeight)
        }

        return TableAttachmentLayout(
            columnWidths: columnWidths,
            rowHeights: rowHeights,
            totalWidth: columnWidths.reduce(0, +) + style.borderWidth,
            totalHeight: rowHeights.reduce(0, +) + style.borderWidth
        )
    }

    private static var minColumnWidth: CGFloat { TableAttachmentStyle.minColumnWidth }
    private static var maxColumnWidth: CGFloat { TableAttachmentStyle.maxColumnWidth }
}

/// A GFM table embedded as a full-width block attachment whose view
/// provider hosts the live grid view.
final class TableAttachment: NSTextAttachment {
    /// Must be a resolvable UTI — NSTextAttachment silently drops any other
    /// string, which breaks the provider-class lookup.
    static let fileType: String = UTType(
        filenameExtension: "enriched-markdown-table"
    )?.identifier ?? "public.data"

    /// UIKit installs the view only via this registration; overriding
    /// `viewProvider(for:...)` on the attachment breaks it.
    private static let providerRegistration: Void = {
        NSTextAttachment.registerViewProviderClass(
            TableAttachmentViewProvider.self,
            forFileType: TableAttachment.fileType
        )
    }()

    let model: TableModel
    let layout: TableAttachmentLayout
    let style: TableAttachmentStyle

    init(model: TableModel, style: TableAttachmentStyle) {
        self.model = model
        self.style = style
        self.layout = TableAttachmentLayout.compute(model: model, style: style)
        _ = Self.providerRegistration
        // fileType only persists with non-nil contents; the data is never read.
        super.init(data: Data("table".utf8), ofType: Self.fileType)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
