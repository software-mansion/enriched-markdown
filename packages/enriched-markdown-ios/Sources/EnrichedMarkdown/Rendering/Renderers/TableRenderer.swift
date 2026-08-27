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
        let style = TableAttachmentStyle(config: config)
        let model = buildModel(from: node, style: style)
        guard !model.rows.isEmpty, model.columnCount > 0 else { return }

        ParagraphStyleHelpers.ensureStartingOnNewLine(in: output)
        if style.marginTop > 0 {
            _ = ParagraphStyleHelpers.applyBlockSpacingBefore(
                to: output,
                at: output.length,
                marginTop: style.marginTop
            )
        }
        let attachment = TableAttachment(model: model, style: style)
        var attributes: [NSAttributedString.Key: Any] = [.attachment: attachment]
        SourceOffsetAnnotator.tagSourceRange(in: &attributes, of: node)
        output.append(NSAttributedString(string: "\u{FFFC}", attributes: attributes))
        output.append(NSAttributedString(string: "\n"))
        ParagraphStyleHelpers.applyBlockSpacingAfter(to: output, marginBottom: style.marginBottom)
    }

    private func buildModel(from node: MarkdownASTNode, style: TableAttachmentStyle) -> TableModel {
        var rows: [[TableCellModel]] = []
        var columnCount = 0
        var columnAlignments: [String?] = []

        for section in node.children where section.type == .tableHead || section.type == .tableBody {
            let sectionIsHead = section.type == .tableHead
            for rowNode in section.children where rowNode.type == .tableRow {
                var cells: [TableCellModel] = []
                for cellNode in rowNode.children
                where cellNode.type == .tableHeaderCell || cellNode.type == .tableCell {
                    let isHeader = sectionIsHead || cellNode.type == .tableHeaderCell
                    let rendered = renderCell(cellNode, isHeader: isHeader, style: style)
                    cells.append(TableCellModel(
                        attributedText: rendered,
                        plainText: rendered.string,
                        markdownText: MarkdownExtractor.inlineMarkdown(for: rendered),
                        isHeader: isHeader
                    ))
                    if sectionIsHead, columnAlignments.count < cells.count {
                        columnAlignments.append(cellNode.attribute("align"))
                    }
                }
                columnCount = max(columnCount, cells.count)
                rows.append(cells)
            }
        }

        while columnAlignments.count < columnCount {
            columnAlignments.append(nil)
        }
        return TableModel(rows: rows, columnCount: columnCount, columnAlignments: columnAlignments)
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
        trimTrailingWhitespace(in: cellOutput)
        applyParagraphStyle(align: cellNode.attribute("align"), style: style, to: cellOutput)
        BaselineShiftRenderer.applyShifts(to: cellOutput, config: config)
        return cellOutput
    }

    private func cellFont(isHeader: Bool, style: TableAttachmentStyle) -> UIFont {
        let base = style.font
            ?? (config.paragraph.font ?? UIFont.preferredFont(forTextStyle: .body)).withSize(style.fontSize)
        guard isHeader else { return base }
        let headerBase = style.headerFont ?? base
        guard let boldDescriptor = headerBase.fontDescriptor.withSymbolicTraits(.traitBold) else {
            return headerBase
        }
        return UIFont(descriptor: boldDescriptor, size: headerBase.pointSize)
    }

    private func applyParagraphStyle(
        align: String?,
        style: TableAttachmentStyle,
        to cellOutput: NSMutableAttributedString
    ) {
        guard cellOutput.length > 0 else { return }
        let paragraphStyle = NSMutableParagraphStyle()
        if style.lineHeight > 0 {
            paragraphStyle.minimumLineHeight = style.lineHeight
            paragraphStyle.maximumLineHeight = style.lineHeight
        }
        switch align {
        case "center": paragraphStyle.alignment = .center
        case "right": paragraphStyle.alignment = .right
        default: break
        }
        cellOutput.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: cellOutput.length)
        )
    }

    private func trimTrailingWhitespace(in cellOutput: NSMutableAttributedString) {
        while cellOutput.length > 0,
              let scalar = Unicode.Scalar((cellOutput.string as NSString).character(at: cellOutput.length - 1)),
              CharacterSet.whitespacesAndNewlines.contains(scalar) {
            cellOutput.deleteCharacters(in: NSRange(location: cellOutput.length - 1, length: 1))
        }
    }
}
