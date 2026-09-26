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

    private func layOut(direction: MarkdownWritingDirection = .firstStrong) throws -> NSTextLayoutManager {
        let rendered = MarkdownRenderer.render(
            Self.markdown,
            config: .baseline(),
            options: MarkdownParsingOptions(admonitions: true),
            writingDirection: direction
        )
        return try XCTUnwrap(laidOutTextView(showing: rendered).textLayoutManager)
    }

    /// The walker must report exactly the line frames and baselines that
    /// `enumerateTextSegments` reports per paragraph; the drawers were
    /// written against the latter.
    func testLinesMatchTextSegments() throws {
        for direction in [MarkdownWritingDirection.firstStrong, .rightToLeft] {
            let textLayoutManager = try layOut(direction: direction)
            let contentManager = try XCTUnwrap(textLayoutManager.textContentManager)
            let paragraphs = ParagraphLayoutWalker.paragraphs(in: textLayoutManager)
            XCTAssertGreaterThan(paragraphs.count, 20)

            var comparedLines = 0
            for paragraph in paragraphs {
                let textRange = try XCTUnwrap(TextLayoutHelpers.textRange(paragraph.range, in: contentManager))
                var segments: [(frame: CGRect, baseline: CGFloat)] = []
                textLayoutManager.enumerateTextSegments(in: textRange, type: .standard, options: []) { _, frame, baseline, _ in
                    segments.append((frame, baseline))
                    return true
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

    func testNeighborsStepThroughTheDocument() throws {
        let textLayoutManager = try layOut()
        let all = ParagraphLayoutWalker.paragraphs(in: textLayoutManager)

        XCTAssertNil(ParagraphLayoutWalker.paragraph(before: all[0], in: textLayoutManager))
        XCTAssertNil(ParagraphLayoutWalker.paragraph(after: all[all.count - 1], in: textLayoutManager))
        for index in 1..<all.count {
            XCTAssertEqual(
                ParagraphLayoutWalker.paragraph(before: all[index], in: textLayoutManager)?.range,
                all[index - 1].range
            )
            XCTAssertEqual(
                ParagraphLayoutWalker.paragraph(after: all[index - 1], in: textLayoutManager)?.range,
                all[index].range
            )
        }
    }
}

private func XCTAssertEqual(_ lhs: CGRect, _ rhs: CGRect, accuracy: CGFloat, _ message: String = "",
                            file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(lhs.minX, rhs.minX, accuracy: accuracy, message, file: file, line: line)
    XCTAssertEqual(lhs.minY, rhs.minY, accuracy: accuracy, message, file: file, line: line)
    XCTAssertEqual(lhs.width, rhs.width, accuracy: accuracy, message, file: file, line: line)
    XCTAssertEqual(lhs.height, rhs.height, accuracy: accuracy, message, file: file, line: line)
}
