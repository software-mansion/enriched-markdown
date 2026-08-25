import UIKit

/// Renders a GFM table as a view-provider attachment; cell content goes
/// through the regular renderer factory.
final class TableRenderer: NodeRenderer {
    private let factory: RendererFactory
    private let config: MarkdownStyleConfig

    init(factory: RendererFactory, config: MarkdownStyleConfig) {
        self.factory = factory
        self.config = config
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let style = TableAttachmentStyle.default
        let model = buildModel(from: node, style: style)
        guard !model.rows.isEmpty, model.columnCount > 0 else { return }

        ParagraphStyleHelpers.ensureStartingOnNewLine(in: output)
        let attachment = TableAttachment(model: model, style: style)
        output.append(NSAttributedString(attachment: attachment))
        output.append(NSAttributedString(string: "\n"))
        ParagraphStyleHelpers.applyBlockSpacingAfter(to: output, marginBottom: style.marginBottom)
    }

    private func buildModel(from node: MarkdownASTNode, style: TableAttachmentStyle) -> TableModel {
        var rows: [[TableCellModel]] = []
        var columnCount = 0

        for section in node.children where section.type == .tableHead || section.type == .tableBody {
            let sectionIsHead = section.type == .tableHead
            for rowNode in section.children where rowNode.type == .tableRow {
                var cells: [TableCellModel] = []
                for cellNode in rowNode.children
                where cellNode.type == .tableHeaderCell || cellNode.type == .tableCell {
                    let isHeader = sectionIsHead || cellNode.type == .tableHeaderCell
                    cells.append(TableCellModel(
                        attributedText: renderCell(cellNode, isHeader: isHeader, style: style),
                        isHeader: isHeader
                    ))
                }
                columnCount = max(columnCount, cells.count)
                rows.append(cells)
            }
        }

        return TableModel(rows: rows, columnCount: columnCount)
    }

    private func renderCell(
        _ cellNode: MarkdownASTNode,
        isHeader: Bool,
        style: TableAttachmentStyle
    ) -> NSAttributedString {
        let cellOutput = NSMutableAttributedString()
        let cellContext = RenderContext()
        cellContext.setBlockStyle(
            font: cellFont(isHeader: isHeader, style: style),
            color: isHeader ? style.headerTextColor : style.textColor
        )
        factory.renderChildren(of: cellNode, into: cellOutput, context: cellContext)
        trimTrailingNewlines(in: cellOutput)
        applyAlignment(cellNode.attribute("align"), to: cellOutput)
        return cellOutput
    }

    private func cellFont(isHeader: Bool, style: TableAttachmentStyle) -> UIFont {
        let base = (config.paragraph.font ?? UIFont.preferredFont(forTextStyle: .body))
            .withSize(style.fontSize)
        guard isHeader else { return base }
        guard let boldDescriptor = base.fontDescriptor.withSymbolicTraits(.traitBold) else {
            return base
        }
        return UIFont(descriptor: boldDescriptor, size: style.fontSize)
    }

    private func applyAlignment(_ align: String?, to cellOutput: NSMutableAttributedString) {
        let alignment: NSTextAlignment
        switch align {
        case "center": alignment = .center
        case "right": alignment = .right
        default: return
        }

        let range = NSRange(location: 0, length: cellOutput.length)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        cellOutput.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
    }

    private func trimTrailingNewlines(in cellOutput: NSMutableAttributedString) {
        while cellOutput.length > 0,
              let scalar = Unicode.Scalar((cellOutput.string as NSString).character(at: cellOutput.length - 1)),
              CharacterSet.whitespacesAndNewlines.contains(scalar) {
            cellOutput.deleteCharacters(in: NSRange(location: cellOutput.length - 1, length: 1))
        }
    }
}
