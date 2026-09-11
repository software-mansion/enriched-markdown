import CoreText
import UIKit

enum ListMarkerDrawer {
    static func draw(in drawContext: MarkerDrawContext) {
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
            let admonition = (attrs[MarkdownAttribute.admonitionHeader] as? String)
                .flatMap(AdmonitionType.init(rawValue:))
            guard admonition != nil || MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.listDepth]) != nil else {
                continue
            }

            let font = (attrs[.font] as? UIFont) ?? UIFont.systemFont(ofSize: 16)
            let isRTL = TextLayoutHelpers.paragraphIsRTL(attrs[.paragraphStyle] as? NSParagraphStyle)
            let layoutInfo = ParagraphMarkerLayout(
                paragraphRange: paragraphRange,
                attrs: attrs,
                gap: admonition == nil ? gap : AdmonitionHeader.iconGap(for: font),
                isRTL: isRTL,
                drawContext: drawContext
            )

            if let admonition {
                drawAdmonitionIcon(
                    admonition,
                    in: layoutInfo.markerRect(size: AdmonitionHeader.iconSize(for: font), font: font, isRTL: isRTL),
                    tint: (attrs[.foregroundColor] as? UIColor) ?? config.blockquoteBorderColor,
                    context: drawContext.context
                )
            } else if let taskValue = attrs[MarkdownAttribute.taskListItem] {
                drawCheckbox(
                    in: layoutInfo.markerRect(size: config.taskCheckboxSize, font: font, isRTL: isRTL),
                    isChecked: MarkdownAttributeValue.boolValue(from: taskValue),
                    config: config,
                    context: drawContext.context
                )
            } else if MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.listType]) == ListType.unordered.rawValue {
                let depth = MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.listDepth]) ?? 0
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

    /// The octicon, scaled from its 16×16 space into `rect`.
    private static func drawAdmonitionIcon(
        _ type: AdmonitionType,
        in rect: CGRect,
        tint: UIColor,
        context: CGContext
    ) {
        guard let path = AdmonitionHeader.iconPath(for: type) else { return }
        let scale = rect.width / AdmonitionHeader.iconViewBox
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: scale, y: scale)
        context.addPath(path)
        context.setFillColor(tint.cgColor)
        context.fillPath()
        context.restoreGState()
    }

    /// Geometry mirrors the React Native package's ListMarkerDrawer so both
    /// renderers produce the same checkbox at the same style values.
    private static func drawCheckbox(
        in rect: CGRect,
        isChecked: Bool,
        config: BlockDecorationConfig,
        context: CGContext
    ) {
        let size = rect.width
        let cornerRadius = min(config.taskCheckboxBorderRadius, size / 2)

        context.saveGState()
        defer { context.restoreGState() }

        if isChecked {
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            context.setFillColor(config.taskCheckedColor.cgColor)
            context.addPath(path.cgPath)
            context.fillPath()

            let inset = size * 0.22
            let midOffset = size * 0.05
            let checkmark = CGMutablePath()
            checkmark.move(to: CGPoint(x: rect.minX + inset, y: rect.midY))
            checkmark.addLine(to: CGPoint(x: rect.midX - midOffset, y: rect.maxY - inset))
            checkmark.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY + inset))
            context.setStrokeColor(config.taskCheckmarkColor.cgColor)
            context.setLineWidth(max(1.5, size * 0.12))
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.addPath(checkmark)
            context.strokePath()
        } else {
            let lineWidth = max(1.0, size * 0.09)
            let insetRect = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            let path = UIBezierPath(roundedRect: insetRect, cornerRadius: cornerRadius)
            context.setStrokeColor(config.taskBorderColor.cgColor)
            context.setLineWidth(lineWidth)
            context.addPath(path.cgPath)
            context.strokePath()
        }
    }
}
