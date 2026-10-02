import UIKit

enum CodeBlockBackgroundDrawer {
    private static let defaultFont = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)

    static func draw(in drawContext: DecorationDrawContext) {
        // Consecutive code paragraphs form one block; the spacer between
        // two blocks carries no attribute, so they never merge.
        for block in drawContext.paragraphs.split(whereSeparator: { !isCode($0) }) {
            drawCodeBlockBackground(for: block, in: drawContext)
        }
    }

    private static func isCode(_ paragraph: ParagraphLayout) -> Bool {
        MarkdownAttributeValue.boolValue(from: paragraph.attributes[MarkdownAttribute.codeBlock])
    }

    /// The block's rect spans from its first line to its last, wherever the
    /// drawn paragraphs cut it: the attribute run gives the whole block's
    /// range, and its end paragraphs are looked up directly rather than
    /// walked to, so a long fence costs the same from any tile.
    private static func drawCodeBlockBackground(for block: ArraySlice<ParagraphLayout>, in drawContext: DecorationDrawContext) {
        let textLayoutManager = drawContext.textLayoutManager
        guard let first = block.first,
              let range = MarkdownAttributeValue.codeBlockRange(in: drawContext.textStorage, at: first.range.location),
              let top = ParagraphLayoutWalker.paragraph(containing: range.location, in: textLayoutManager),
              let bottom = ParagraphLayoutWalker.paragraph(containing: NSMaxRange(range) - 1, in: textLayoutManager)
        else { return }

        var blockRect = CGRect.null
        for paragraph in [top, bottom] {
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
