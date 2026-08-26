import CoreText
import UIKit

enum ListMarkerDrawer {
    static func draw(in drawContext: ListDrawContext) {
        let visibleCharacterRange = drawContext.visibleCharacterRange
        guard visibleCharacterRange.length > 0 else { return }

        let config = drawContext.decorationConfig
        let gap = config.listGapWidth
        let string = drawContext.textStorage.string as NSString
        var drawnParagraphs = Set<Int>()
        var location = visibleCharacterRange.location
        let end = NSMaxRange(visibleCharacterRange)

        while location < end {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            defer { location = NSMaxRange(paragraphRange) }

            guard paragraphRange.length > 0,
                  paragraphRange.location < drawContext.textStorage.length,
                  !drawnParagraphs.contains(paragraphRange.location) else {
                continue
            }
            drawnParagraphs.insert(paragraphRange.location)

            let attrs = drawContext.textStorage.attributes(at: paragraphRange.location, effectiveRange: nil)
            guard MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.listDepth]) != nil else {
                continue
            }

            let isRTL = paragraphIsRTL(attrs[.paragraphStyle] as? NSParagraphStyle)
            let layoutInfo = layoutInfo(
                ParagraphLayoutRequest(
                    paragraphRange: paragraphRange,
                    textLayoutManager: drawContext.textLayoutManager,
                    contentManager: drawContext.contentManager,
                    attrs: attrs,
                    gap: gap,
                    origin: drawContext.origin,
                    isRTL: isRTL
                )
            )

            if MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.listType]) == ListType.unordered.rawValue {
                let depth = MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.listDepth]) ?? 0
                let font = (attrs[.font] as? UIFont) ?? UIFont.systemFont(ofSize: 16)
                let bulletY = bulletCenterY(visualBaselineY: layoutInfo.visualBaselineY, font: font)
                drawBullet(at: CGPoint(x: layoutInfo.markerX, y: bulletY), depth: depth, config: config, in: drawContext.context)
            } else if let number = MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.listItemNumber]) {
                drawOrderedMarker(
                    at: layoutInfo.markerX,
                    number: number,
                    baselineY: layoutInfo.visualBaselineY,
                    isRTL: isRTL,
                    config: config,
                    in: drawContext.context
                )
            }
        }
    }

    private struct ParagraphLayoutInfo {
        let markerX: CGFloat
        let visualBaselineY: CGFloat
    }

    private struct ParagraphLayoutRequest {
        let paragraphRange: NSRange
        let textLayoutManager: NSTextLayoutManager
        let contentManager: NSTextContentManager
        let attrs: [NSAttributedString.Key: Any]
        let gap: CGFloat
        let origin: CGPoint
        let isRTL: Bool
    }

    private static func layoutInfo(_ request: ParagraphLayoutRequest) -> ParagraphLayoutInfo {
        let paragraphStyle = request.attrs[.paragraphStyle] as? NSParagraphStyle
        let textStartX = paragraphStyle?.headIndent ?? paragraphStyle?.firstLineHeadIndent ?? 0
        let font = (request.attrs[.font] as? UIFont) ?? UIFont.systemFont(ofSize: 16)
        var segmentFrame = CGRect(x: textStartX, y: 0, width: 0, height: 0)
        var baselineFromLineTop = font.ascender

        if let textRange = TextLayoutHelpers.textRange(request.paragraphRange, in: request.contentManager) {
            request.textLayoutManager.enumerateTextSegments(
                in: textRange,
                type: .standard,
                options: []
            ) { _, frame, baseline, _ in
                segmentFrame = frame
                baselineFromLineTop = baseline
                return false
            }
        }

        let layoutBaselineY = request.origin.y + segmentFrame.minY + baselineFromLineTop
        let baselineOffset = CGFloat((request.attrs[.baselineOffset] as? NSNumber)?.doubleValue ?? 0)
        let visualBaselineY = layoutBaselineY - baselineOffset

        let markerX: CGFloat
        if request.isRTL {
            let textEndX = max(segmentFrame.maxX, textStartX)
            markerX = request.origin.x + textEndX + request.gap
        } else {
            let textOriginX = segmentFrame.width > 0 ? segmentFrame.minX : textStartX
            markerX = request.origin.x + textOriginX - request.gap
        }

        return ParagraphLayoutInfo(markerX: markerX, visualBaselineY: visualBaselineY)
    }

    private static func bulletCenterY(visualBaselineY: CGFloat, font: UIFont) -> CGFloat {
        visualBaselineY - typographicXHeight(for: font) / 2
    }

    private static func typographicXHeight(for font: UIFont) -> CGFloat {
        let xHeight = CTFontGetXHeight(font as CTFont)
        return xHeight > 0 ? xHeight : font.capHeight * 0.7
    }

    private static func drawBullet(
        at point: CGPoint,
        depth: Int,
        config: BlockDecorationConfig,
        in context: CGContext
    ) {
        let size = config.listBulletSize
        let rect = CGRect(
            x: point.x - size / 2,
            y: point.y - size / 2,
            width: size,
            height: size
        )

        context.saveGState()
        switch depth {
        case 0:
            context.setFillColor(config.listBulletColor.cgColor)
            context.fillEllipse(in: rect)
        case 1:
            let lineWidth = max(1, size * 0.15)
            context.setStrokeColor(config.listBulletColor.cgColor)
            context.setLineWidth(lineWidth)
            context.strokeEllipse(in: rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
        default:
            context.setFillColor(config.listBulletColor.cgColor)
            context.fill(rect)
        }
        context.restoreGState()
    }

    private static func drawOrderedMarker(
        at boundaryX: CGFloat,
        number: Int,
        baselineY: CGFloat,
        isRTL: Bool,
        config: BlockDecorationConfig,
        in context: CGContext
    ) {
        let text = isRTL ? ".\(number)" : "\(number)."
        let attributes: [NSAttributedString.Key: Any] = [
            .font: config.listMarkerFont,
            .foregroundColor: config.listMarkerColor
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let drawX = isRTL ? boundaryX : boundaryX - size.width
        (text as NSString).draw(
            at: CGPoint(x: drawX, y: baselineY - config.listMarkerFont.ascender),
            withAttributes: attributes
        )
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
