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
                    let geometry = InlineBackgroundDrawer.LineGeometry(line: line, paragraph: paragraph, in: drawContext)
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
                let geometry = InlineBackgroundDrawer.LineGeometry(line: line, paragraph: paragraph, in: drawContext)
                XCTAssertEqual(geometry.usesCarets, expected, text)
                XCTAssertEqual(InlineBackgroundDrawer.hasOrderedCarets(line, in: textView.textStorage), expected, text)
            }
            checked.insert(String(text.prefix(5)))
        }
        XCTAssertEqual(checked.count, 5)
    }

    func testBoxesCoverEachLinePieceOfALinkAtTheFontHeight() throws {
        let textView = textView(width: 200)
        let drawContext = try drawContext(for: textView)
        let boxes = InlineBackgroundDrawer.boxes(in: drawContext)
        let string = textView.textStorage.mutableString

        var expected: [CGRect] = []
        textView.textStorage.enumerateAttribute(.link, in: NSRange(location: 0, length: textView.textStorage.length)) { value, range, _ in
            guard value != nil,
                  let font = textView.textStorage.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
            else { return }
            TextLayoutHelpers.enumerateSegmentFrames(of: range, in: textView) { frame, _, baseline in
                expected.append(CGRect(
                    x: frame.minX,
                    y: frame.minY + baseline - font.ascender,
                    width: frame.width,
                    height: font.ascender - font.descender
                ))
            }
        }
        XCTAssertEqual(boxes.count, expected.count)
        XCTAssertGreaterThan(boxes.count, 9, "the long mention wraps: \(string)")
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

    func testFillIsDrawnBehindTheLinkOnlyAndTheBorderAboveIt() throws {
        let rendered = MarkdownRenderer.render("Ask [alice](user://alice) plain", config: config)
        let textView = laidOutTextView(showing: rendered, config: config)
        let string = rendered.string as NSString
        let linkFrame = frame(of: string.range(of: "alice"), in: textView)
        let plainFrame = frame(of: string.range(of: "plain"), in: textView)
        let linkCenter = CGPoint(x: linkFrame.midX, y: linkFrame.midY)
        let plainCenter = CGPoint(x: plainFrame.midX, y: plainFrame.midY)
        let white: [UInt8] = [255, 255, 255, 255]

        XCTAssertEqual(try backgroundPixel(of: textView, at: linkCenter).sorted(), [51, 102, 153, 255])
        XCTAssertEqual(try backgroundPixel(of: textView, at: plainCenter), white)

        let box = try XCTUnwrap(InlineBackgroundDrawer.boxes(in: drawContext(for: textView)).first)
        let onBorder = CGPoint(x: box.rect.midX, y: box.rect.minY + 1)
        XCTAssertNotEqual(try backgroundPixel(of: textView, at: onBorder, pass: .foreground), white)
        XCTAssertEqual(try backgroundPixel(of: textView, at: linkCenter, pass: .foreground), white)
        XCTAssertEqual(try backgroundPixel(of: textView, at: onBorder, pass: .background).sorted(), [51, 102, 153, 255])
    }
}
