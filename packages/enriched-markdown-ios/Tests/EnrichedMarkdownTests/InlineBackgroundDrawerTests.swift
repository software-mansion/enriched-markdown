import UIKit
import XCTest
@testable import EnrichedMarkdown

final class InlineBackgroundDrawerTests: XCTestCase {
    private static let markdown = """
    Ask [alice](user://alice) or [bob](user://bob) about the long line that wraps onto a second line for sure, [carol](user://carol) too.

    - A list item with [dave](user://dave) inside

    שאל את [אליס](user://alice) או [בוב](user://bob) על זה

    מספרים 12 ו[אליס42](user://alice) כאן

    Hello שלום [eve](user://eve) world [פרנק](user://frank) end

    A [very long mention name that surely wraps across two lines in a narrow view](user://long) here.
    """

    private let fill = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
    private let fillPixel: [UInt8] = [51, 102, 153, 255]
    private let red: [UInt8] = [0, 0, 255, 255]
    private let white: [UInt8] = [255, 255, 255, 255]
    private var config: MarkdownStyleConfiguration!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfiguration.baseline(traitCollection: UITraitCollection(userInterfaceStyle: .light))
        config.linkVariants = [LinkVariantStyle(
            pattern: "^user:",
            style: ElementStyle(backgroundColor: fill, borderColor: .red, borderWidth: 2, cornerRadius: 4)
        )]
    }

    private func textView(direction: MarkdownWritingDirection = .firstStrong, width: CGFloat = 390) -> MarkdownTextView {
        let rendered = MarkdownRenderer.render(Self.markdown, config: config, writingDirection: direction)
        return laidOutTextView(showing: rendered, width: width, config: config)
    }

    private func drawContext(for textView: MarkdownTextView) throws -> DecorationDrawContext {
        let textLayoutManager = try XCTUnwrap(textView.textLayoutManager)
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        return DecorationDrawContext(
            context: context,
            paragraphs: ParagraphLayoutWalker.paragraphs(in: textLayoutManager),
            textStorage: textView.textStorage,
            textLayoutManager: textLayoutManager,
            containerWidth: textView.textContainer.size.width,
            origin: .zero,
            decorationConfig: BlockDecorationConfig(styleConfig: config),
            trailingPadding: 0
        )
    }

    private func geometry(
        of line: LineLayout, in paragraph: ParagraphLayout, of textView: MarkdownTextView
    ) throws -> InlineBackgroundDrawer.LineGeometry {
        InlineBackgroundDrawer.LineGeometry(
            line: line, paragraph: paragraph,
            textStorage: textView.textStorage, textLayoutManager: try XCTUnwrap(textView.textLayoutManager)
        )
    }

    private func boxes(of textView: MarkdownTextView) throws -> [InlineBackgroundDrawer.Box] {
        InlineBackgroundDrawer.layout(in: try drawContext(for: textView)).boxes.sorted { $0.rect.minX < $1.rect.minX }
    }

    private func expectedBoxes(of range: NSRange, in textView: MarkdownTextView) throws -> [CGRect] {
        let font = try XCTUnwrap(textView.textStorage.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont)
        let shift = MarkdownAttributeValue.baselineOffset(in: textView.textStorage.attributes(at: range.location, effectiveRange: nil))
        var rects: [CGRect] = []
        TextLayoutHelpers.enumerateSegmentFrames(of: range, in: textView) { frame, _, baseline in
            rects.append(CGRect(
                x: frame.minX,
                y: frame.minY + baseline - shift - font.ascender,
                width: frame.width,
                height: font.ascender - font.descender
            ))
        }
        return rects
    }

    private func center(of word: String, in textView: MarkdownTextView) -> CGPoint {
        let frame = frame(of: (textView.textStorage.string as NSString).range(of: word), in: textView)
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    private func words(in range: NSRange, of string: NSString) -> [NSRange] {
        var words: [NSRange] = []
        string.enumerateSubstrings(in: range, options: [.byWords, .substringNotRequired]) { _, wordRange, _, _ in
            words.append(wordRange)
        }
        return words
    }

    private func segmentSpans(of range: NSRange, in textView: MarkdownTextView) -> [ClosedRange<CGFloat>] {
        var spans: [ClosedRange<CGFloat>] = []
        TextLayoutHelpers.enumerateSegmentFrames(of: range, in: textView) { frame, _, _ in
            if frame.width > 0 {
                spans.append(frame.minX...frame.maxX)
            }
        }
        return spans.sorted { $0.lowerBound < $1.lowerBound }
    }

    private func assertSpans(_ spans: [ClosedRange<CGFloat>], match expected: [ClosedRange<CGFloat>], _ label: String) {
        let sorted = spans.sorted { $0.lowerBound < $1.lowerBound }
        XCTAssertEqual(sorted.count, expected.count, label)
        for (span, segment) in zip(sorted, expected) {
            XCTAssertEqual(span.lowerBound, segment.lowerBound, accuracy: 0.01, label)
            XCTAssertEqual(span.upperBound, segment.upperBound, accuracy: 0.01, label)
        }
    }

    func testSpansMatchTextSegmentsForEveryWord() throws {
        for direction in [MarkdownWritingDirection.firstStrong, .rightToLeft] {
            let textView = textView(direction: direction)
            let drawContext = try drawContext(for: textView)
            let string = textView.textStorage.mutableString
            var compared = 0
            for paragraph in drawContext.paragraphs {
                for line in paragraph.lines {
                    let geometry = try geometry(of: line, in: paragraph, of: textView)
                    for word in words(in: line.range, of: string) {
                        let label = "'\(string.substring(with: word))' \(direction)"
                        assertSpans(geometry.spans(of: word), match: segmentSpans(of: word, in: textView), label)
                        compared += 1
                    }
                }
            }
            XCTAssertGreaterThan(compared, 40, "\(direction)")
        }
    }

    func testOnlyLinesMixingDirectionsFallBackToTextSegments() throws {
        let textView = textView()
        let drawContext = try drawContext(for: textView)
        let string = textView.textStorage.mutableString
        var checked: Set<String> = []
        for paragraph in drawContext.paragraphs {
            let text = string.substring(with: paragraph.range)
            let expected: Bool
            if text.hasPrefix("Ask") || text.hasPrefix("שאל") || text.hasPrefix("A very") {
                expected = true
            } else if text.hasPrefix("Hello") || text.hasPrefix("מספרים") {
                expected = false
            } else {
                continue
            }
            for line in paragraph.lines {
                XCTAssertEqual(try geometry(of: line, in: paragraph, of: textView).usesCarets, expected, text)
                XCTAssertEqual(InlineBackgroundDrawer.hasOrderedCarets(line, in: textView.textStorage), expected, text)
            }
            checked.insert(String(text.prefix(5)))
        }
        XCTAssertEqual(checked.count, 5)
    }

    func testBoxesCoverEachLinePieceOfALinkAtTheFontHeight() throws {
        let textView = textView(width: 200)
        let boxes = try boxes(of: textView)

        var expected: [CGRect] = []
        textView.textStorage.enumerateAttribute(.link, in: NSRange(location: 0, length: textView.textStorage.length)) { value, range, _ in
            guard value != nil, let rects = try? expectedBoxes(of: range, in: textView) else { return }
            expected += rects
        }
        XCTAssertEqual(boxes.count, expected.count)
        XCTAssertGreaterThan(boxes.count, 9, "the long mention wraps: \(textView.textStorage.string)")
        let byPosition: (CGRect, CGRect) -> Bool = { ($0.minY, $0.minX) < ($1.minY, $1.minX) }
        for (box, rect) in zip(boxes.sorted { byPosition($0.rect, $1.rect) }, expected.sorted(by: byPosition)) {
            XCTAssertEqual(box.rect, rect, accuracy: 0.01)
            XCTAssertEqual(box.background.cornerRadius, 4)
        }
    }

    func testTheTextViewNotesWhetherAnyLinkIsDrawn() {
        for markdown in ["Ask [alice](user://alice) plain", "[alice](user://alice) first"] {
            let drawn = MarkdownRenderer.render(markdown, config: config)
            XCTAssertTrue(laidOutTextView(showing: drawn, config: config).hasInlineBackgrounds, markdown)
        }

        let plainConfig = MarkdownStyleConfiguration.baseline()
        let plain = MarkdownRenderer.render("Ask [alice](user://alice) plain", config: plainConfig)
        XCTAssertFalse(laidOutTextView(showing: plain, config: plainConfig).hasInlineBackgrounds)
    }

    func testFillAndBorderAreBothDrawnBeneathTheText() throws {
        let rendered = MarkdownRenderer.render("Ask [alice](user://alice) plain", config: config)
        let textView = laidOutTextView(showing: rendered, config: config)
        let linkCenter = center(of: "alice", in: textView)
        let plainCenter = center(of: "plain", in: textView)

        XCTAssertEqual(try backgroundPixel(of: textView, at: linkCenter).sorted(), fillPixel)
        XCTAssertEqual(try backgroundPixel(of: textView, at: plainCenter), white)

        let box = try XCTUnwrap(boxes(of: textView).first)
        let onBorder = CGPoint(x: box.rect.midX, y: box.rect.minY - 1)
        let justInside = CGPoint(x: box.rect.midX, y: box.rect.minY + 1)
        XCTAssertEqual(try backgroundPixel(of: textView, at: onBorder).sorted(), red, "the border wraps the box")
        XCTAssertEqual(try backgroundPixel(of: textView, at: justInside).sorted(), fillPixel, "the fill reaches the box edge")
        XCTAssertEqual(try backgroundPixel(of: textView, at: onBorder, pass: .foreground), white)
        XCTAssertEqual(try backgroundPixel(of: textView, at: linkCenter, pass: .foreground), white)
    }

    func testBoxesFollowTextRaisedByALineHeight() throws {
        config.paragraph.lineHeight = 32
        let rendered = MarkdownRenderer.render("Ask [alice](user://alice) plain", config: config)
        let textView = laidOutTextView(showing: rendered, config: config)
        let range = (rendered.string as NSString).range(of: "alice")
        XCTAssertGreaterThan(MarkdownAttributeValue.baselineOffset(in: rendered.attributes(at: range.location, effectiveRange: nil)), 0)

        let box = try XCTUnwrap(boxes(of: textView).first)
        XCTAssertEqual(box.rect, try XCTUnwrap(expectedBoxes(of: range, in: textView).first), accuracy: 0.01)
    }

    func testNeighbouringLinksKeepSeparateBoxes() throws {
        for (markdown, second) in [
            ("[alice](user://alice)[bob](user://bob)", "bob"),
            ("[alice](user://alice)[alice](user://alice)", "alice")
        ] {
            let rendered = MarkdownRenderer.render(markdown, config: config)
            let textView = laidOutTextView(showing: rendered, config: config)
            let boxes = try boxes(of: textView)
            XCTAssertEqual(boxes.count, 2, markdown)
            guard boxes.count == 2 else { continue }

            let string = rendered.string as NSString
            let first = string.range(of: "alice")
            let rest = NSRange(location: NSMaxRange(first), length: string.length - NSMaxRange(first))
            XCTAssertEqual(boxes[0].rect.width, frame(of: first, in: textView).width, accuracy: 0.01, markdown)
            XCTAssertEqual(
                boxes[1].rect.width, frame(of: string.range(of: second, range: rest), in: textView).width, accuracy: 0.01, markdown
            )
            XCTAssertEqual(boxes[0].rect.maxX, boxes[1].rect.minX, accuracy: 0.01, markdown)
        }
    }

    func testAnImageLinkIsBoxedAroundTheImage() throws {
        config.inlineImage.size = 30
        let rendered = MarkdownRenderer.render(
            "only [![](https://example.invalid/a.png)](user://a), then [![](https://example.invalid/b.png) label](user://b)",
            config: config
        )
        let textView = laidOutTextView(showing: rendered, config: config)
        let drawContext = try drawContext(for: textView)
        let boxes = InlineBackgroundDrawer.layout(in: drawContext).boxes.sorted { $0.rect.minX < $1.rect.minX }
        XCTAssertEqual(boxes.count, 2)
        guard boxes.count == 2 else { return }

        let paragraph = try XCTUnwrap(drawContext.paragraphs.first)
        let string = rendered.string as NSString
        let firstImage = string.range(of: "\u{FFFC}")
        let afterFirst = NSRange(location: NSMaxRange(firstImage), length: string.length - NSMaxRange(firstImage))
        let secondImage = string.range(of: "\u{FFFC}", range: afterFirst)
        let firstFrame = try XCTUnwrap(paragraph.attachmentFrame(at: firstImage.location))
        let secondFrame = try XCTUnwrap(paragraph.attachmentFrame(at: secondImage.location))
        XCTAssertEqual(firstFrame.size, CGSize(width: 34, height: 34), "the image reserves the 2 pt border around itself")
        XCTAssertEqual(boxes[0].rect, firstFrame.insetBy(dx: 2, dy: 2), accuracy: 0.01, "an image alone is its own box")
        XCTAssertGreaterThanOrEqual(boxes[0].rect.minY - 2, -0.01, "the stroke above the image stays in the view")
        XCTAssertEqual(try backgroundPixel(of: textView, at: CGPoint(x: boxes[0].rect.midX, y: boxes[0].rect.minY - 1)).sorted(), red)

        let label = try XCTUnwrap(expectedBoxes(of: string.range(of: "label"), in: textView).first)
        XCTAssertEqual(boxes[1].rect.maxX, label.maxX, accuracy: 0.01)
        XCTAssertLessThanOrEqual(boxes[1].rect.minY, label.minY + 0.01, "covers the text")
        XCTAssertGreaterThanOrEqual(boxes[1].rect.maxY, label.maxY - 0.01)
        XCTAssertEqual(boxes[1].rect.minX, secondFrame.minX + 2, accuracy: 0.01)
        XCTAssertLessThanOrEqual(boxes[1].rect.minY, secondFrame.minY + 2.01, "covers the image")
        XCTAssertGreaterThanOrEqual(boxes[1].rect.maxY, secondFrame.maxY - 2.01)
    }

    func testTheBoxTopMeetsTheRaisedGlyphs() throws {
        config.paragraph.lineHeight = 32
        config.linkVariants = [LinkVariantStyle(
            pattern: "^user:",
            style: ElementStyle(foregroundColor: .black, backgroundColor: fill, underline: false, cornerRadius: 4)
        )]
        let rendered = MarkdownRenderer.render("Ask [alice](user://alice) plain", config: config)
        let textView = laidOutTextView(showing: rendered, config: config)
        textView.layer.displayIfNeeded()
        let rows = try renderedRows(size: textView.bounds.size) { textView.layer.render(in: $0) }

        let range = (rendered.string as NSString).range(of: "alice")
        let linkFrame = frame(of: range, in: textView)
        let font = try XCTUnwrap(rendered.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont)
        let inkTop = try XCTUnwrap(rows.indices.first { row in
            (Int(linkFrame.minX)..<Int(linkFrame.maxX)).contains { column in
                pixel(in: rows, column: column, row: row).prefix(3).allSatisfy { $0 < 100 }
            }
        })

        let box = try XCTUnwrap(boxes(of: textView).first)
        XCTAssertGreaterThanOrEqual(CGFloat(inkTop), box.rect.minY - 0.5, "ink above the box")
        XCTAssertLessThanOrEqual(CGFloat(inkTop), box.rect.minY + font.ascender - font.capHeight + 1, "ink far below the box top")
    }

    func testAHighlightUnderABorderedLinkIsPaintedBeneathItsBorder() throws {
        config.highlight.backgroundColor = UIColor(red: 1, green: 0.8, blue: 0, alpha: 1)
        config.linkVariants = [LinkVariantStyle(
            pattern: "^user:",
            style: ElementStyle(borderColor: .red, borderWidth: 2, cornerRadius: 4)
        )]
        let rendered = MarkdownRenderer.render(
            "==see [alice](user://alice) here==", config: config, options: MarkdownParsingOptions(highlight: true)
        )
        let textView = laidOutTextView(showing: rendered, config: config)
        let highlight: [UInt8] = [0, 204, 255, 255]

        XCTAssertEqual(try backgroundPixel(of: textView, at: center(of: "alice", in: textView)).sorted(), highlight)
        let box = try XCTUnwrap(boxes(of: textView).first)
        XCTAssertEqual(try backgroundPixel(of: textView, at: CGPoint(x: box.rect.midX, y: box.rect.minY - 1)).sorted(), red)
        XCTAssertEqual(try backgroundPixel(of: textView, at: CGPoint(x: box.rect.midX, y: box.rect.minY + 1)).sorted(), highlight)
    }

    func testInlineCodeKeepsItsChipOverTheLinkFill() throws {
        config.code.backgroundColor = UIColor(red: 0, green: 0.6, blue: 0.2, alpha: 1)
        let rendered = MarkdownRenderer.render("[`alice` profile](user://alice)", config: config)
        let textView = laidOutTextView(showing: rendered, config: config)

        XCTAssertEqual(try backgroundPixel(of: textView, at: center(of: "alice", in: textView)).sorted(), [0, 51, 153, 255])
        XCTAssertEqual(try backgroundPixel(of: textView, at: center(of: "profile", in: textView)).sorted(), fillPixel)
    }

    func testAThickBorderFitsInsideItsLine() throws {
        config.linkVariants = [LinkVariantStyle(
            pattern: "^user:",
            style: ElementStyle(borderColor: .red, borderWidth: 4, cornerRadius: 6)
        )]
        for markdown in ["Ask [alice](user://alice) plain", "First line.\n\nAsk [alice](user://alice) plain"] {
            let rendered = MarkdownRenderer.render(markdown, config: config)
            let textView = laidOutTextView(showing: rendered, config: config)
            let box = try XCTUnwrap(boxes(of: textView).first, markdown)

            XCTAssertGreaterThanOrEqual(box.rect.minY - 4, -0.01, "the top stroke stays in the view: \(markdown)")
            XCTAssertLessThanOrEqual(box.rect.maxY + 4, textView.bounds.height + 0.01, "the bottom stroke stays in the view: \(markdown)")
            XCTAssertEqual(try backgroundPixel(of: textView, at: CGPoint(x: box.rect.midX, y: box.rect.minY - 2)).sorted(), red, markdown)
            XCTAssertEqual(try backgroundPixel(of: textView, at: CGPoint(x: box.rect.midX, y: box.rect.maxY + 2)).sorted(), red, markdown)
        }
    }

    func testTheStrokeStaysVisibleInsideAHighlightAndAtTheMargin() throws {
        config.highlight.backgroundColor = UIColor(red: 1, green: 0.8, blue: 0, alpha: 1)
        let rendered = MarkdownRenderer.render(
            "[alice](user://alice) starts, ==then [bob](user://bob) sits in a highlight==",
            config: config, options: MarkdownParsingOptions(highlight: true)
        )
        let textView = laidOutTextView(showing: rendered, config: config)
        XCTAssertEqual(textView.textContainer.lineFragmentPadding, 2, "the widest border pads the lines")
        textView.layer.displayIfNeeded()
        let rows = try renderedRows(size: textView.bounds.size) { textView.layer.render(in: $0) }
        func sortedPixel(at point: CGPoint) -> [UInt8] { pixel(in: rows, column: Int(point.x), row: Int(point.y)).sorted() }

        let boxes = try boxes(of: textView)
        XCTAssertEqual(boxes.count, 2)
        guard boxes.count == 2 else { return }
        XCTAssertGreaterThanOrEqual(boxes[0].rect.minX, 2, "the first chip starts after the padding")
        assertNear(sortedPixel(at: CGPoint(x: boxes[0].rect.minX - 1, y: boxes[0].rect.midY)), red, "left stroke at the margin")
        assertNear(sortedPixel(at: CGPoint(x: boxes[1].rect.minX - 1, y: boxes[1].rect.midY)), red, "left stroke inside the highlight")
        assertNear(sortedPixel(at: CGPoint(x: boxes[1].rect.maxX + 1, y: boxes[1].rect.midY)), red, "right stroke inside the highlight")
        assertNear(sortedPixel(at: CGPoint(x: boxes[1].rect.minX - 8, y: boxes[1].rect.midY)), [0, 204, 255, 255], "the highlight is still painted")
    }

    private func assertNear(_ pixel: [UInt8], _ expected: [UInt8], _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        for (channel, wanted) in zip(pixel, expected) {
            XCTAssertEqual(Int(channel), Int(wanted), accuracy: 12, "\(label): \(pixel)", file: file, line: line)
        }
    }

    func testAThinBorderAddsNoHeight() {
        let bordered = MarkdownRenderer.render("Ask [alice](user://alice) plain", config: config)
        let plain = MarkdownRenderer.render("Ask alice plain", config: config)

        XCTAssertEqual(
            laidOutTextView(showing: bordered, config: config).bounds.height,
            laidOutTextView(showing: plain, config: config).bounds.height
        )
    }
}
