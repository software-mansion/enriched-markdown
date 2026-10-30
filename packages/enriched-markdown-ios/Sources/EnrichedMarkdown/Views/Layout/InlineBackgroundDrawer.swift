import UIKit

protocol InlineBackgroundLine {
    var baselineY: CGFloat { get }
    func visualBaselineY(at offset: Int) -> CGFloat
    func spans(of range: NSRange) -> [ClosedRange<CGFloat>]
    func attachmentFrame(at offset: Int) -> CGRect?
}

enum InlineBackgroundDrawer {
    struct Box {
        let background: InlineBackground.Style
        let rect: CGRect

        var strokedRect: CGRect {
            let width = background.border?.width ?? 0
            return rect.insetBy(dx: -width, dy: -width)
        }
    }

    struct Underlay {
        let color: UIColor
        let rect: CGRect
    }

    struct Layout {
        var boxes: [Box] = []
        var underlays: [Underlay] = []
    }

    private struct Run {
        let style: InlineBackground.Style?
        let linkStart: Int?
        var range: NSRange
        var underlays: [(color: UIColor, range: NSRange)] = []
    }

    private struct Shape {
        let ascent: CGFloat
        let descent: CGFloat
        let spans: [ClosedRange<CGFloat>]
    }

    struct LineGeometry: InlineBackgroundLine {
        private let line: LineLayout
        private let paragraph: ParagraphLayout
        private let textStorage: NSTextStorage
        private let textLayoutManager: NSTextLayoutManager
        let usesCarets: Bool

        init(line: LineLayout, paragraph: ParagraphLayout, textStorage: NSTextStorage, textLayoutManager: NSTextLayoutManager) {
            self.line = line
            self.paragraph = paragraph
            self.textStorage = textStorage
            self.textLayoutManager = textLayoutManager
            let paragraphIsRTL = TextLayoutHelpers.paragraphIsRTL(paragraph.attributes[.paragraphStyle] as? NSParagraphStyle)
            let rightToLeft = textStorage.mutableString.rangeOfCharacter(
                from: WritingDirectionResolver.rightToLeftCharacters, options: [], range: line.range
            )
            usesCarets = (!paragraphIsRTL && rightToLeft.location == NSNotFound)
                || InlineBackgroundDrawer.hasOrderedCarets(line, in: textStorage)
        }

        var baselineY: CGFloat { line.bounds.minY + line.baselineOffset }

        func visualBaselineY(at offset: Int) -> CGFloat {
            baselineY - MarkdownAttributeValue.baselineOffset(in: textStorage.attributes(at: offset, effectiveRange: nil))
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

        func attachmentFrame(at offset: Int) -> CGRect? {
            paragraph.attachmentFrame(at: offset)
        }
    }

    private struct CellLine: InlineBackgroundLine {
        let layoutManager: NSLayoutManager
        let container: NSTextContainer
        let fragment: CGRect
        let baselineY: CGFloat

        init(stack: TextKit1Stack, fragment: CGRect, glyphRange: NSRange) {
            layoutManager = stack.layoutManager
            container = stack.container
            self.fragment = fragment
            baselineY = fragment.minY + stack.layoutManager.location(forGlyphAt: glyphRange.location).y
        }

        func visualBaselineY(at offset: Int) -> CGFloat {
            fragment.minY + layoutManager.location(forGlyphAt: layoutManager.glyphIndexForCharacter(at: offset)).y
        }

        func spans(of piece: NSRange) -> [ClosedRange<CGFloat>] {
            let glyphs = layoutManager.glyphRange(forCharacterRange: piece, actualCharacterRange: nil)
            let noSelection = NSRange(location: NSNotFound, length: 0)
            var spans: [ClosedRange<CGFloat>] = []
            layoutManager.enumerateEnclosingRects(forGlyphRange: glyphs, withinSelectedGlyphRange: noSelection, in: container) { rect, _ in
                if rect.width > 0 {
                    spans.append(rect.minX...rect.maxX)
                }
            }
            return spans
        }

        func attachmentFrame(at offset: Int) -> CGRect? {
            guard let textStorage = layoutManager.textStorage,
                  let attachment = textStorage.attribute(.attachment, at: offset, effectiveRange: nil) as? NSTextAttachment
            else { return nil }
            let location = layoutManager.location(forGlyphAt: layoutManager.glyphIndexForCharacter(at: offset))
            let bounds = attachment.attachmentBounds(
                for: container, proposedLineFragment: fragment, glyphPosition: location, characterIndex: offset
            )
            return CGRect(
                x: fragment.minX + location.x + bounds.minX,
                y: fragment.minY + location.y - bounds.maxY,
                width: bounds.width,
                height: bounds.height
            )
        }
    }

    static func draw(in drawContext: DecorationDrawContext) {
        paint(layout(in: drawContext), in: drawContext.context)
    }

    static func layout(in drawContext: DecorationDrawContext) -> Layout {
        layout(
            of: drawContext.paragraphs, in: drawContext.textStorage,
            textLayoutManager: drawContext.textLayoutManager, origin: drawContext.origin
        )
    }

    static func layout(
        of paragraphs: [ParagraphLayout],
        in textStorage: NSTextStorage,
        textLayoutManager: NSTextLayoutManager,
        origin: CGPoint = .zero
    ) -> Layout {
        var layout = Layout()
        for paragraph in paragraphs {
            for line in paragraph.lines {
                let runs = runs(in: line.range, of: textStorage)
                guard !runs.isEmpty else { continue }
                let geometry = LineGeometry(
                    line: line, paragraph: paragraph, textStorage: textStorage, textLayoutManager: textLayoutManager
                )
                add(runs, on: geometry, in: textStorage, origin: origin, to: &layout)
            }
        }
        return layout
    }

    static func layout(of text: NSAttributedString, width: CGFloat) -> Layout {
        var layout = Layout()
        guard InlineBackground.isPresent(in: text) else { return layout }
        let stack = TextKit1Stack(text: text, size: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        let glyphs = stack.layoutManager.glyphRange(for: stack.container)
        stack.layoutManager.enumerateLineFragments(forGlyphRange: glyphs) { fragment, _, _, glyphRange, _ in
            let range = stack.layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let runs = runs(in: range, of: stack.storage)
            guard !runs.isEmpty else { return }
            let line = CellLine(stack: stack, fragment: fragment, glyphRange: glyphRange)
            add(runs, on: line, in: stack.storage, to: &layout)
        }
        return layout
    }

    static func paint(_ layout: Layout, in context: CGContext) {
        guard !layout.boxes.isEmpty else { return }
        let byStyle = Dictionary(grouping: layout.boxes, by: \.background)
        context.saveGState()
        for (style, boxes) in byStyle {
            guard let fill = style.fillColor else { continue }
            context.setFillColor(fill.cgColor)
            context.addPath(path(around: boxes.map(\.rect), cornerRadius: style.cornerRadius))
            context.fillPath()
        }
        for (color, underlays) in Dictionary(grouping: layout.underlays, by: \.color) {
            context.setFillColor(color.cgColor)
            context.fill(underlays.map(\.rect))
        }
        for (style, boxes) in byStyle {
            guard let border = style.border else { continue }
            let outset = border.width / 2
            context.setStrokeColor(border.color.cgColor)
            context.setLineWidth(border.width)
            context.addPath(path(
                around: boxes.map { $0.strokedRect.insetBy(dx: outset, dy: outset) },
                cornerRadius: style.cornerRadius + outset
            ))
            context.strokePath()
        }
        context.restoreGState()
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

    private static func runs(in range: NSRange, of text: NSAttributedString) -> [Run] {
        var runs: [Run] = []
        text.enumerateAttribute(MarkdownAttribute.inlineBackground, in: range, options: []) { value, piece, _ in
            guard let background = value as? InlineBackground else { return }
            if let last = runs.indices.last, runs[last].linkStart == background.linkStart {
                runs[last].range = NSUnionRange(runs[last].range, piece)
            } else {
                runs.append(Run(style: background.style, linkStart: background.linkStart, range: piece))
            }
            if let underlay = background.underlay {
                runs[runs.count - 1].underlays.append((underlay, piece))
            }
        }
        text.enumerateAttribute(MarkdownAttribute.drawnHighlight, in: range, options: []) { value, piece, _ in
            guard let color = value as? UIColor else { return }
            runs.append(Run(style: nil, linkStart: nil, range: piece, underlays: [(color, piece)]))
        }
        return runs
    }

    private static func add(
        _ runs: [Run],
        on line: some InlineBackgroundLine,
        in text: NSAttributedString,
        origin: CGPoint = .zero,
        to layout: inout Layout
    ) {
        for run in runs {
            guard let shape = shape(of: run.range, on: line, in: text) else { continue }
            let top = origin.y + line.baselineY - shape.ascent
            let height = shape.ascent + shape.descent
            let rect = { (span: ClosedRange<CGFloat>) in
                CGRect(x: origin.x + span.lowerBound, y: top, width: span.upperBound - span.lowerBound, height: height)
            }
            if let style = run.style {
                layout.boxes += shape.spans.map { Box(background: style, rect: rect($0)) }
            }
            for underlay in run.underlays {
                layout.underlays += line.spans(of: underlay.range)
                    .filter { $0.upperBound > $0.lowerBound }
                    .map { Underlay(color: underlay.color, rect: rect($0)) }
            }
        }
    }

    private static func shape(
        of range: NSRange,
        on line: some InlineBackgroundLine,
        in text: NSAttributedString
    ) -> Shape? {
        var ascent = -CGFloat.greatestFiniteMagnitude
        var descent = -CGFloat.greatestFiniteMagnitude
        var paddedFrames: [(frame: CGRect, padding: CGFloat)] = []
        text.enumerateAttributes(in: range, options: []) { attributes, run, _ in
            if let attachment = attributes[.attachment] as? NSTextAttachment, let frame = line.attachmentFrame(at: run.location) {
                let padding = (attachment as? MarkdownImageAttachment)?.padding ?? 0
                let content = frame.insetBy(dx: padding, dy: padding)
                ascent = max(ascent, line.baselineY - content.minY)
                descent = max(descent, content.maxY - line.baselineY)
                if padding > 0 {
                    paddedFrames.append((frame, padding))
                }
            } else if let font = attributes[.font] as? UIFont {
                let raise = line.baselineY - line.visualBaselineY(at: run.location)
                ascent = max(ascent, font.ascender + raise)
                descent = max(descent, -font.descender - raise)
            }
        }
        guard ascent + descent > 0 else { return nil }
        let spans = line.spans(of: range).compactMap { span -> ClosedRange<CGFloat>? in
            var lower = span.lowerBound
            var upper = span.upperBound
            for edge in paddedFrames {
                if abs(edge.frame.minX - lower) < 0.5 {
                    lower += edge.padding
                }
                if abs(edge.frame.maxX - upper) < 0.5 {
                    upper -= edge.padding
                }
            }
            return upper > lower ? lower...upper : nil
        }
        return Shape(ascent: ascent, descent: descent, spans: spans)
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
