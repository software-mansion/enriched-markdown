import UIKit

enum InlineBackgroundDrawer {
    struct Box {
        let background: InlineBackground
        let rect: CGRect
    }

    struct LineGeometry {
        private let line: LineLayout
        private let textLayoutManager: NSTextLayoutManager
        let usesCarets: Bool

        init(line: LineLayout, paragraph: ParagraphLayout, in drawContext: DecorationDrawContext) {
            self.line = line
            textLayoutManager = drawContext.textLayoutManager
            let textStorage = drawContext.textStorage
            let paragraphIsRTL = TextLayoutHelpers.paragraphIsRTL(paragraph.attributes[.paragraphStyle] as? NSParagraphStyle)
            let rightToLeft = textStorage.mutableString.rangeOfCharacter(
                from: WritingDirectionResolver.rightToLeftCharacters, options: [], range: line.range
            )
            usesCarets = (!paragraphIsRTL && rightToLeft.location == NSNotFound)
                || InlineBackgroundDrawer.hasOrderedCarets(line, in: textStorage)
        }

        func spans(of piece: NSRange) -> [ClosedRange<CGFloat>] {
            if usesCarets {
                let start = line.caretX(at: piece.location)
                let end = line.caretX(at: NSMaxRange(piece))
                return [min(start, end)...max(start, end)]
            }
            var spans: [ClosedRange<CGFloat>] = []
            TextLayoutHelpers.enumerateSegmentFrames(of: piece, in: textLayoutManager) { frame, _, _ in
                if frame.width > 0 {
                    spans.append(frame.minX...frame.maxX)
                }
            }
            return spans
        }
    }

    static func drawFills(in drawContext: DecorationDrawContext) {
        let context = drawContext.context
        context.saveGState()
        for (background, rects) in rects(in: drawContext) {
            guard let fill = background.fillColor else { continue }
            context.setFillColor(fill.cgColor)
            context.addPath(path(around: rects, cornerRadius: background.cornerRadius))
            context.fillPath()
        }
        context.restoreGState()
    }

    static func drawBorders(in drawContext: DecorationDrawContext) {
        let context = drawContext.context
        context.saveGState()
        for (background, rects) in rects(in: drawContext) {
            guard let border = background.border else { continue }
            let inset = border.width / 2
            context.setStrokeColor(border.color.cgColor)
            context.setLineWidth(border.width)
            context.addPath(path(
                around: rects.map { $0.insetBy(dx: inset, dy: inset) },
                cornerRadius: max(0, background.cornerRadius - inset)
            ))
            context.strokePath()
        }
        context.restoreGState()
    }

    static func boxes(in drawContext: DecorationDrawContext) -> [Box] {
        let textStorage = drawContext.textStorage
        var boxes: [Box] = []
        for paragraph in drawContext.paragraphs {
            for line in paragraph.lines {
                var geometry: LineGeometry?
                let baselineY = drawContext.origin.y + line.bounds.minY + line.baselineOffset
                textStorage.enumerateAttribute(MarkdownAttribute.inlineBackground, in: line.range, options: []) { value, piece, _ in
                    guard let background = value as? InlineBackground else { return }
                    let lineGeometry = geometry ?? LineGeometry(line: line, paragraph: paragraph, in: drawContext)
                    geometry = lineGeometry
                    let (ascent, descent) = verticalExtent(of: piece, in: textStorage)
                    for span in lineGeometry.spans(of: piece) where span.upperBound > span.lowerBound {
                        boxes.append(Box(background: background, rect: CGRect(
                            x: drawContext.origin.x + span.lowerBound,
                            y: baselineY - ascent,
                            width: span.upperBound - span.lowerBound,
                            height: ascent + descent
                        )))
                    }
                }
            }
        }
        return boxes
    }

    static func hasOrderedCarets(_ line: LineLayout, in textStorage: NSTextStorage) -> Bool {
        let string = textStorage.mutableString
        var end = NSMaxRange(line.range)
        if end > line.range.location, Unicode.Scalar(string.character(at: end - 1)).map(CharacterSet.newlines.contains) == true {
            end -= 1
        }
        guard end - line.range.location > 1 else { return true }

        var index = line.range.location
        var previous = line.caretX(at: index)
        var direction: CGFloat = 0
        while index < end {
            index = NSMaxRange(string.rangeOfComposedCharacterSequence(at: index))
            let caret = line.caretX(at: index)
            let step = caret - previous
            if step == 0 { return false }
            if direction == 0 {
                direction = step
            } else if (step > 0) != (direction > 0) {
                return false
            }
            previous = caret
        }
        return true
    }

    private static func rects(in drawContext: DecorationDrawContext) -> [InlineBackground: [CGRect]] {
        Dictionary(grouping: boxes(in: drawContext), by: \.background).mapValues { $0.map(\.rect) }
    }

    private static func verticalExtent(of range: NSRange, in textStorage: NSTextStorage) -> (ascent: CGFloat, descent: CGFloat) {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, _, _ in
            guard let font = value as? UIFont else { return }
            ascent = max(ascent, font.ascender)
            descent = max(descent, -font.descender)
        }
        return (ascent, descent)
    }

    private static func path(around rects: [CGRect], cornerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for rect in rects where !rect.isEmpty {
            let radius = min(cornerRadius, rect.width / 2, rect.height / 2)
            path.addRoundedRect(in: rect, cornerWidth: radius, cornerHeight: radius)
        }
        return path
    }
}
