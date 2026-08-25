import UIKit
import UniformTypeIdentifiers

struct TableCellModel: Equatable {
    let attributedText: NSAttributedString
    let plainText: String
    /// Cell content with inline markdown markers restored (bold, code,
    /// links, …), for Copy as Markdown.
    let markdownText: String
    let isHeader: Bool
}

struct TableModel: Equatable {
    let rows: [[TableCellModel]]
    let columnCount: Int
    /// Raw `align` attribute per column ("left"/"center"/"right"/nil),
    /// taken from the header row; used to rebuild markdown separators.
    let columnAlignments: [String?]
}

/// Style values resolved from `MarkdownStyleConfig.table`, with RN-parity
/// fallbacks for unset keys.
struct TableAttachmentStyle: Equatable {
    static let `default` = TableAttachmentStyle()

    var font: UIFont?
    var fontSize: CGFloat = 14
    var lineHeight: CGFloat = 20
    var textColor = UIColor.label
    var headerTextColor = UIColor.label
    var headerBackground = UIColor.tertiarySystemFill
    var rowEvenBackground = UIColor.clear
    var rowOddBackground = UIColor.quaternarySystemFill
    var borderColor = UIColor.separator
    var borderWidth: CGFloat = 1
    var cornerRadius: CGFloat = 6
    var cellPaddingHorizontal: CGFloat = 12
    var cellPaddingVertical: CGFloat = 8
    var marginTop: CGFloat = 0
    var marginBottom: CGFloat = 16
    var align: TableAlignment = .leading

    static let minColumnWidth: CGFloat = 60
    static let maxColumnWidth: CGFloat = 300

    init() {}

    init(config: MarkdownStyleConfig) {
        applyColors(from: config.table)
        applyMetrics(from: config.table)
    }

    private mutating func applyColors(from table: TableStyle) {
        if let value = table.foregroundColor { textColor = value }
        if let value = table.headerTextColor { headerTextColor = value }
        if let value = table.headerBackgroundColor { headerBackground = value }
        if let value = table.rowEvenBackgroundColor { rowEvenBackground = value }
        if let value = table.rowOddBackgroundColor { rowOddBackground = value }
        if let value = table.borderColor { borderColor = value }
    }

    private mutating func applyMetrics(from table: TableStyle) {
        if let value = table.font {
            font = value
            fontSize = value.pointSize
        }
        if let value = table.lineHeight { lineHeight = value }
        if let value = table.borderWidth { borderWidth = value }
        if let value = table.borderRadius { cornerRadius = value }
        if let value = table.cellPaddingHorizontal { cellPaddingHorizontal = value }
        if let value = table.cellPaddingVertical { cellPaddingVertical = value }
        if let value = table.marginTop { marginTop = value }
        if let value = table.marginBottom { marginBottom = value }
        if let value = table.align { align = value }
    }
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

    /// TextKit 2 recreates the provider view whenever the table re-enters
    /// the viewport; the horizontal scroll position survives here.
    var preservedContentOffset: CGPoint = .zero

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

    /// Tab-separated plain text for the pasteboard and accessibility.
    func plainText() -> String {
        model.rows
            .map { row in row.map(\.plainText).joined(separator: "\t") }
            .joined(separator: "\n")
    }

    /// Rebuilds the pipe table, with a separator row derived from the
    /// column alignments.
    func markdownText() -> String {
        var lines: [String] = []
        for (index, row) in model.rows.enumerated() {
            let cells = (0..<model.columnCount).map { column in
                column < row.count ? row[column].markdownText.replacingOccurrences(of: "|", with: "\\|") : ""
            }
            lines.append("| " + cells.joined(separator: " | ") + " |")

            if index == 0 {
                let separators = (0..<model.columnCount).map { column -> String in
                    switch model.columnAlignments[safe: column] ?? nil {
                    case "center": return ":---:"
                    case "right": return "---:"
                    case "left": return ":---"
                    default: return "---"
                    }
                }
                lines.append("| " + separators.joined(separator: " | ") + " |")
            }
        }
        return lines.joined(separator: "\n")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
