import UIKit

enum CodeBlockBackgroundDrawer {
    private static let defaultFont = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)

    static func draw(in drawContext: DecorationDrawContext) {
        // Consecutive code paragraphs form one block; the spacer between
        // two blocks carries no attribute, so they never merge.
        for block in drawContext.paragraphs.split(whereSeparator: { !isCode($0) }) {
            drawCodeBlockBackground(for: completed(block, in: drawContext.textLayoutManager), in: drawContext)
        }
    }

    private static func isCode(_ paragraph: ParagraphLayout) -> Bool {
        MarkdownAttributeValue.boolValue(from: paragraph.attributes[MarkdownAttribute.codeBlock])
    }

    /// The whole block when the drawn paragraphs cut it: its rounded
    /// corners belong at the block's ends, not at the cut.
    private static func completed(
        _ block: ArraySlice<ParagraphLayout>,
        in textLayoutManager: NSTextLayoutManager
    ) -> [ParagraphLayout] {
        var block = Array(block)
        while let first = block.first,
              let previous = ParagraphLayoutWalker.paragraph(before: first, in: textLayoutManager),
              isCode(previous) {
            block.insert(previous, at: 0)
        }
        while let last = block.last,
              let next = ParagraphLayoutWalker.paragraph(after: last, in: textLayoutManager),
              isCode(next) {
            block.append(next)
        }
        return block
    }

    private static func drawCodeBlockBackground(for block: [ParagraphLayout], in drawContext: DecorationDrawContext) {
        var blockRect = CGRect.null
        for paragraph in block {
            // CodeBlockRenderer sets one font over the block's content; the
            // padding spacers carry none and measure with the default.
            let font = paragraph.attributes[.font] as? UIFont ?? defaultFont
            for line in paragraph.lines {
                let baselineY = line.bounds.minY + line.baselineOffset
                blockRect = blockRect.union(CGRect(
                    x: line.bounds.minX,
                    y: baselineY - font.ascender,
                    width: line.bounds.width,
                    height: font.ascender - font.descender
                ))
            }
        }
        guard !blockRect.isNull else { return }

        blockRect.origin.x = drawContext.origin.x
        blockRect.origin.y += drawContext.origin.y
        blockRect.size.width = drawContext.containerWidth

        let config = drawContext.decorationConfig
        let borderWidth = config.codeBlockBorderWidth
        let inset = borderWidth / 2
        let insetRect = blockRect.insetBy(dx: inset, dy: inset)
        let cornerRadius = max(0, config.codeBlockBorderRadius - inset)

        drawContext.context.saveGState()
        drawContext.context.setFillColor(config.codeBlockBackgroundColor.cgColor)
        let path = UIBezierPath(roundedRect: insetRect, cornerRadius: cornerRadius)
        drawContext.context.addPath(path.cgPath)
        drawContext.context.fillPath()

        if borderWidth > 0 {
            drawContext.context.setStrokeColor(config.codeBlockBorderColor.cgColor)
            drawContext.context.setLineWidth(borderWidth)
            drawContext.context.addPath(path.cgPath)
            drawContext.context.strokePath()
        }
        drawContext.context.restoreGState()
    }
}
