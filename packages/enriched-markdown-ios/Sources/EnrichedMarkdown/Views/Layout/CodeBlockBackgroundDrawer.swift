import UIKit

enum CodeBlockBackgroundDrawer {
    static func draw(in drawContext: BlockDrawContext) {
        drawContext.textStorage.enumerateAttribute(
            MarkdownAttribute.codeBlock,
            in: NSRange(location: 0, length: drawContext.textStorage.length),
            options: []
        ) { value, range, _ in
            guard value != nil, TextLayoutHelpers.rangesIntersect(range, drawContext.visibleCharacterRange) else { return }
            drawCodeBlockBackground(for: range, in: drawContext)
        }
    }

    private static func drawCodeBlockBackground(for range: NSRange, in drawContext: BlockDrawContext) {
        let textStorage = drawContext.textStorage
        guard range.location < textStorage.length else { return }

        let clampedRange = NSRange(
            location: range.location,
            length: min(range.length, textStorage.length - range.location)
        )
        guard clampedRange.length > 0,
              let textRange = TextLayoutHelpers.textRange(clampedRange, in: drawContext.contentManager) else {
            return
        }

        let defaultFont = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        var blockRect = CGRect.null

        drawContext.textLayoutManager.enumerateTextSegments(
            in: textRange,
            type: .standard,
            options: []
        ) { textSegmentRange, segmentFrame, baselineOffset, _ in
            let segmentRange = textSegmentRange.flatMap {
                TextLayoutHelpers.nsRange($0, in: drawContext.contentManager)
            }
            let font = font(
                forSegmentAt: segmentRange,
                fallbackRange: clampedRange,
                defaultFont: defaultFont,
                in: textStorage
            )
            let baselineY = segmentFrame.minY + baselineOffset
            let typographicFrame = CGRect(
                x: segmentFrame.minX,
                y: baselineY - font.ascender,
                width: segmentFrame.width,
                height: font.ascender - font.descender
            )
            if blockRect.isNull {
                blockRect = typographicFrame
            } else {
                blockRect = blockRect.union(typographicFrame)
            }
            return true
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

    private static func font(
        forSegmentAt segmentRange: NSRange?,
        fallbackRange: NSRange,
        defaultFont: UIFont,
        in textStorage: NSTextStorage
    ) -> UIFont {
        guard textStorage.length > 0 else { return defaultFont }

        var candidates: [Int] = []
        if let segmentRange, segmentRange.location != NSNotFound {
            candidates.append(segmentRange.location)
        }
        candidates.append(fallbackRange.location)
        if fallbackRange.length > 0 {
            candidates.append(fallbackRange.location + fallbackRange.length - 1)
        }

        for index in candidates {
            guard index >= 0, index < textStorage.length else { continue }
            if let font = textStorage.attribute(.font, at: index, effectiveRange: nil) as? UIFont {
                return font
            }
        }

        return defaultFont
    }
}
