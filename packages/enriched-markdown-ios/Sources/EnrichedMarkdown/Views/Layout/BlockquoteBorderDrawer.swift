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

            drawContext.context.saveGState()
            drawContext.context.setFillColor(bgColor.cgColor)
            drawContext.context.fill(CGRect(
                x: drawContext.origin.x,
                y: drawContext.origin.y + paragraphFrame.origin.y,
                width: drawContext.containerWidth,
                height: paragraphFrame.height
            ))
            drawContext.context.restoreGState()
        }
    }

    static func drawBorders(in drawContext: BlockDrawContext) {
        let config = drawContext.decorationConfig
        let borderWidth = config.blockquoteBorderWidth
        let gapWidth = config.blockquoteGapWidth
        let levelSpacing = borderWidth + gapWidth
        let borderColor = config.blockquoteBorderColor
        var borderPath = UIBezierPath()

        enumerateBlockquoteParagraphs(in: drawContext) { attrs, paragraphFrame, depthNum in
            let baseY = drawContext.origin.y + paragraphFrame.origin.y
            let isRTL = paragraphIsRTL(attrs[.paragraphStyle] as? NSParagraphStyle)

            for level in 0 ... depthNum {
                let borderX = isRTL
                    ? drawContext.origin.x + drawContext.containerWidth - borderWidth - (levelSpacing * CGFloat(level))
                    : drawContext.origin.x + (levelSpacing * CGFloat(level))
                let borderRect = CGRect(x: borderX, y: baseY, width: borderWidth, height: paragraphFrame.height)
                borderPath.append(UIBezierPath(rect: borderRect))
            }
        }

        if !borderPath.isEmpty {
            drawContext.context.saveGState()
            drawContext.context.setFillColor(borderColor.cgColor)
            drawContext.context.addPath(borderPath.cgPath)
            drawContext.context.fillPath()
            drawContext.context.restoreGState()
        }
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

            let paragraphFrame = paragraphFrame(
                for: paragraphRange,
                textLayoutManager: drawContext.textLayoutManager,
                contentManager: drawContext.contentManager
            )
            guard !paragraphFrame.isNull else { continue }

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

    private static func paragraphIsRTL(_ style: NSParagraphStyle?) -> Bool {
        guard let style else {
            return UIView.userInterfaceLayoutDirection(
                for: UIView.appearance().semanticContentAttribute
            ) == .rightToLeft
        }
        if style.baseWritingDirection != .natural {
            return style.baseWritingDirection == .rightToLeft
        }
        return UIView.userInterfaceLayoutDirection(
            for: UIView.appearance().semanticContentAttribute
        ) == .rightToLeft
    }
}
