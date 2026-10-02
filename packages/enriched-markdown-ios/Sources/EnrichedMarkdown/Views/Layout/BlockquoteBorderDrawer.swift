import UIKit

enum BlockquoteBorderDrawer {
    static func draw(in drawContext: DecorationDrawContext) {
        drawBackgrounds(in: drawContext)
        drawBorders(in: drawContext)
    }

    static func drawBackgrounds(in drawContext: DecorationDrawContext) {
        enumerateBlockquoteParagraphs(in: drawContext) { attrs, paragraphFrame, _ in
            let bgColor = (attrs[MarkdownAttribute.blockquoteBackgroundColor] as? UIColor)
                ?? drawContext.decorationConfig.blockquoteBackgroundColor
            guard bgColor.cgColor.alpha > 0 else { return }

            let offset = attrs[MarkdownAttribute.blockquoteBarOffset] as? CGFloat ?? 0
            let isRTL = TextLayoutHelpers.paragraphIsRTL(attrs[.paragraphStyle] as? NSParagraphStyle)
            drawContext.context.saveGState()
            drawContext.context.setFillColor(bgColor.cgColor)
            drawContext.context.fill(CGRect(
                x: drawContext.origin.x + (isRTL ? 0 : offset),
                y: drawContext.origin.y + paragraphFrame.origin.y,
                width: drawContext.containerWidth - offset,
                height: paragraphFrame.height
            ))
            drawContext.context.restoreGState()
        }
    }

    /// One bar per nesting level, in the level's baked color (an
    /// admonition's tint) or the plain border color, batched per color.
    static func drawBorders(in drawContext: DecorationDrawContext) {
        let config = drawContext.decorationConfig
        let borderWidth = config.blockquoteBorderWidth
        let levelSpacing = borderWidth + config.blockquoteGapWidth
        var barRects: [UIColor: [CGRect]] = [:]

        enumerateBlockquoteParagraphs(in: drawContext) { attrs, paragraphFrame, depthNum in
            let baseY = drawContext.origin.y + paragraphFrame.origin.y
            let isRTL = TextLayoutHelpers.paragraphIsRTL(attrs[.paragraphStyle] as? NSParagraphStyle)
            let barColors = attrs[MarkdownAttribute.blockquoteBarColors] as? [UIColor] ?? []
            let offset = attrs[MarkdownAttribute.blockquoteBarOffset] as? CGFloat ?? 0

            for level in 0 ... depthNum {
                let levelX = offset + levelSpacing * CGFloat(level)
                let borderX = isRTL
                    ? drawContext.origin.x + drawContext.containerWidth - borderWidth - levelX
                    : drawContext.origin.x + levelX
                let color = level < barColors.count ? barColors[level] : config.blockquoteBorderColor
                barRects[color, default: []].append(
                    CGRect(x: borderX, y: baseY, width: borderWidth, height: paragraphFrame.height)
                )
            }
        }

        drawContext.context.saveGState()
        for (color, rects) in barRects {
            drawContext.context.setFillColor(color.cgColor)
            drawContext.context.fill(rects)
        }
        drawContext.context.restoreGState()
    }

    private static func enumerateBlockquoteParagraphs(
        in drawContext: DecorationDrawContext,
        handler: ([NSAttributedString.Key: Any], CGRect, Int) -> Void
    ) {
        for paragraph in drawContext.paragraphs {
            let attrs = paragraph.attributes
            guard let depthNum = MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.blockquoteDepth]) else {
                continue
            }
            var paragraphFrame = paragraph.frame
            guard !paragraphFrame.isNull else { continue }

            // Line frames exclude paragraph spacing (an admonition title's
            // gap, a heading's margin); the bar and fill must run through it.
            paragraphFrame.size.height += (attrs[.paragraphStyle] as? NSParagraphStyle)?.paragraphSpacing ?? 0
            handler(attrs, paragraphFrame, depthNum)
        }
    }
}
