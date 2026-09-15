import UIKit

enum BlockquoteBorderDrawer {
    static func draw(in drawContext: BlockDrawContext) {
        drawBackgrounds(in: drawContext)
        drawBorders(in: drawContext)
    }

    static func drawBackgrounds(in drawContext: BlockDrawContext) {
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
    static func drawBorders(in drawContext: BlockDrawContext) {
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
        in drawContext: BlockDrawContext,
        handler: ([NSAttributedString.Key: Any], CGRect, Int) -> Void
    ) {
        let visibleCharacterRange = drawContext.visibleCharacterRange
        guard visibleCharacterRange.length > 0 else { return }

        let string = drawContext.textStorage.string as NSString
        var location = visibleCharacterRange.location
        let end = NSMaxRange(visibleCharacterRange)

        while location < end {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            defer { location = NSMaxRange(paragraphRange) }

            guard paragraphRange.length > 0, paragraphRange.location < drawContext.textStorage.length else { continue }

            let attrs = drawContext.textStorage.attributes(at: paragraphRange.location, effectiveRange: nil)
            guard let depthNum = MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.blockquoteDepth]) else {
                continue
            }

            var paragraphFrame = paragraphFrame(
                for: paragraphRange,
                textLayoutManager: drawContext.textLayoutManager,
                contentManager: drawContext.contentManager
            )
            guard !paragraphFrame.isNull else { continue }

            // Line frames exclude paragraph spacing (an admonition title's
            // gap, a heading's margin); the bar and fill must run through it.
            paragraphFrame.size.height += (attrs[.paragraphStyle] as? NSParagraphStyle)?.paragraphSpacing ?? 0
            handler(attrs, paragraphFrame, depthNum)
        }
    }

    private static func paragraphFrame(
        for paragraphRange: NSRange,
        textLayoutManager: NSTextLayoutManager,
        contentManager: NSTextContentManager
    ) -> CGRect {
        guard let textRange = TextLayoutHelpers.textRange(paragraphRange, in: contentManager) else {
            return .null
        }

        var paragraphFrame = CGRect.null
        textLayoutManager.enumerateTextSegments(
            in: textRange,
            type: .standard,
            options: []
        ) { _, segmentFrame, _, _ in
            if paragraphFrame.isNull {
                paragraphFrame = segmentFrame
            } else {
                paragraphFrame = paragraphFrame.union(segmentFrame)
            }
            return true
        }
        return paragraphFrame
    }
}
