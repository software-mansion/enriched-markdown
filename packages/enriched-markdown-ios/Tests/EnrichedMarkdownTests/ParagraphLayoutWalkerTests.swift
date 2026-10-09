import UIKit
import XCTest
@testable import EnrichedMarkdown

final class ParagraphLayoutWalkerTests: XCTestCase {
    private static let markdown = """
    # Heading

    Paragraph one that is long enough to wrap onto a second line for sure yes it wraps around.

    - Item one
      - Nested item
        1. Deep ordered
    - [ ] Task item
    - [x] Done item
    - Item with quote
      > quoted in item

    > Quote line
    > > Nested quote

    > [!NOTE]
    > Admonition body

    ```swift
    let x = 1
    print(x)
    ```

    שלום עולם זה משפט בעברית

    1. First
    2. Second

    ---

    End.
    """

    private func layOutTextView(direction: MarkdownWritingDirection = .firstStrong) -> MarkdownTextView {
        let rendered = MarkdownRenderer.render(
            Self.markdown,
            config: .baseline(),
            options: MarkdownParsingOptions(admonitions: true),
            writingDirection: direction
        )
        return laidOutTextView(showing: rendered)
    }

    private func layOut(direction: MarkdownWritingDirection = .firstStrong) throws -> NSTextLayoutManager {
        try XCTUnwrap(layOutTextView(direction: direction).textLayoutManager)
    }

    /// The walker must report exactly the line frames and baselines that
    /// the segment enumeration reports per paragraph; the drawers were
    /// written against the latter.
    func testLinesMatchTextSegments() throws {
        for direction in [MarkdownWritingDirection.firstStrong, .rightToLeft] {
            let textView = layOutTextView(direction: direction)
            let textLayoutManager = try XCTUnwrap(textView.textLayoutManager)
            let paragraphs = ParagraphLayoutWalker.paragraphs(in: textLayoutManager)
            XCTAssertGreaterThan(paragraphs.count, 20)

            var comparedLines = 0
            for paragraph in paragraphs {
                var segments: [(frame: CGRect, baseline: CGFloat)] = []
                TextLayoutHelpers.enumerateSegmentFrames(of: paragraph.range, in: textView) { frame, _, baseline in
                    segments.append((frame, baseline))
                }
                XCTAssertEqual(segments.count, paragraph.lines.count, "lines of \(paragraph.range)")
                for (segment, line) in zip(segments, paragraph.lines) {
                    XCTAssertEqual(segment.frame, line.bounds, accuracy: 0.001, "bounds of \(paragraph.range)")
                    XCTAssertEqual(segment.baseline, line.baselineOffset, accuracy: 0.001, "baseline of \(paragraph.range)")
                    comparedLines += 1
                }
            }
            XCTAssertGreaterThan(comparedLines, 20)
        }
    }

    func testAttributesComeFromTheParagraphStart() throws {
        let textLayoutManager = try layOut()
        let textStorage = try XCTUnwrap((textLayoutManager.textContentManager as? NSTextContentStorage)?.textStorage)
        let paragraphs = ParagraphLayoutWalker.paragraphs(in: textLayoutManager)

        XCTAssertEqual(paragraphs.filter { $0.attributes[MarkdownAttribute.listDepth] != nil }.count, 8)
        XCTAssertEqual(paragraphs.filter { $0.attributes[MarkdownAttribute.blockquoteDepth] != nil }.count, 5)
        XCTAssertEqual(
            paragraphs.filter { MarkdownAttributeValue.boolValue(from: $0.attributes[MarkdownAttribute.codeBlock]) }.count,
            4
        )
        for paragraph in paragraphs {
            let expected = textStorage.attributes(at: paragraph.range.location, effectiveRange: nil)
            XCTAssertEqual(paragraph.attributes as NSDictionary, expected as NSDictionary)
        }
    }

    func testWalkBoundedToARectCoversItsParagraphs() throws {
        let textLayoutManager = try layOut()
        let all = ParagraphLayoutWalker.paragraphs(in: textLayoutManager)
        let rect = CGRect(x: 0, y: 200, width: 390, height: 150)
        let some = ParagraphLayoutWalker.paragraphs(in: textLayoutManager, intersecting: rect)

        XCTAssertFalse(some.isEmpty)
        XCTAssertLessThan(some.count, all.count)

        // A contiguous run of the full walk...
        let first = try XCTUnwrap(all.firstIndex { $0.range == some[0].range })
        XCTAssertEqual(some.map(\.range), all[first..<(first + some.count)].map(\.range))

        // ...holding every paragraph that touches the rect.
        for paragraph in all where paragraph.frame.intersects(rect) {
            XCTAssertTrue(some.contains { $0.range == paragraph.range }, "paragraph at \(paragraph.frame)")
        }
    }

    func testParagraphContainingAnOffset() throws {
        let textLayoutManager = try layOut()
        let all = ParagraphLayoutWalker.paragraphs(in: textLayoutManager)

        for paragraph in all {
            for offset in [paragraph.range.location, NSMaxRange(paragraph.range) - 1] {
                XCTAssertEqual(
                    ParagraphLayoutWalker.paragraph(containing: offset, in: textLayoutManager)?.range,
                    paragraph.range,
                    "offset \(offset)"
                )
            }
        }
        let end = try XCTUnwrap(all.last).range
        XCTAssertNil(ParagraphLayoutWalker.paragraph(containing: NSMaxRange(end), in: textLayoutManager))
        XCTAssertNil(ParagraphLayoutWalker.paragraph(containing: -1, in: textLayoutManager))
    }

    /// A host that draws before TextKit laid out the drawn region still
    /// gets lines: the walker lays such a fragment out itself.
    func testWalkLaysOutFragmentsOutsideTheViewport() throws {
        let rendered = MarkdownRenderer.render((1...200).map { "- Item \($0)" }.joined(separator: "\n"), config: .baseline())
        // A scrolling text view lays out only its viewport, the first 200 points.
        let textView = UITextView(usingTextLayoutManager: true)
        textView.frame = CGRect(x: 0, y: 0, width: 390, height: 200)
        textView.attributedText = rendered
        textView.layoutIfNeeded()
        let textLayoutManager = try XCTUnwrap(textView.textLayoutManager)

        let far = CGRect(x: 0, y: 2000, width: 390, height: 300)
        let paragraphs = ParagraphLayoutWalker.paragraphs(in: textLayoutManager, intersecting: far)
        XCTAssertGreaterThan(paragraphs.count, 5)
        for paragraph in paragraphs {
            XCTAssertFalse(paragraph.lines.isEmpty, "paragraph at \(paragraph.range)")
        }
        let first = try XCTUnwrap(paragraphs.first)
        let last = try XCTUnwrap(paragraphs.last)
        XCTAssertLessThanOrEqual(first.frame.minY, far.minY)
        XCTAssertGreaterThan(first.frame.maxY, far.minY)
        XCTAssertGreaterThanOrEqual(last.frame.maxY, far.maxY)

        // A lookup by offset lays its fragment out the same way.
        let lastItem = ParagraphLayoutWalker.paragraph(containing: textView.textStorage.length - 2, in: textLayoutManager)
        XCTAssertFalse(try XCTUnwrap(lastItem).lines.isEmpty)
    }
}
