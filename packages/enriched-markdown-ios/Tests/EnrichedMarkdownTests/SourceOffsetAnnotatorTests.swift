import XCTest
@testable import EnrichedMarkdown

final class SourceOffsetAnnotatorTests: XCTestCase {
    private func annotate(_ source: String) -> MarkdownASTNode {
        SourceOffsetAnnotator.annotate(Parser.shared.parseMarkdown(source), source: source)
    }

    private func range(of node: MarkdownASTNode?) -> (start: Int, end: Int)? {
        node.flatMap(SourceOffsetAnnotator.sourceRange(of:))
    }

    func testTextNodesCarrySourceOffsets() {
        let ast = annotate("hello **bold** world")
        let texts = ast.all(ofType: .text)

        let hello = texts.first { $0.content == "hello " }
        let bold = texts.first { $0.content == "bold" }
        XCTAssertEqual(range(of: hello)?.start, 0)
        XCTAssertEqual(range(of: hello)?.end, 6)
        XCTAssertEqual(range(of: bold)?.start, 8)
        XCTAssertEqual(range(of: bold)?.end, 12)
    }

    func testContainerNodesAggregateChildOffsets() {
        let source = "hello **bold** world"
        let ast = annotate(source)

        // The strong span covers its text (not the ** markers); the
        // paragraph covers all of its literal text.
        let strong = range(of: ast.first(ofType: .strong))
        XCTAssertEqual(strong?.start, 8)
        XCTAssertEqual(strong?.end, 12)
        let paragraph = range(of: ast.first(ofType: .paragraph))
        XCTAssertEqual(paragraph?.start, 0)
        XCTAssertEqual(paragraph?.end, source.utf8.count)
    }

    func testTableNodesAggregateCellOffsets() {
        let ast = annotate("| A |\n|---|\n| xyz |")

        let table = range(of: ast.first(ofType: .table))
        XCTAssertEqual(table?.start, 2)
        XCTAssertEqual(table?.end, 17)
        let cell = range(of: ast.first(ofType: .tableCell))
        XCTAssertEqual(cell?.start, 14)
        XCTAssertEqual(cell?.end, 17)
    }

    /// Break characters have no text node of their own; the paragraph's
    /// aggregated range spans across them.
    func testParagraphAggregatesAcrossSoftBreak() {
        let ast = annotate("first\nsecond")

        let paragraph = range(of: ast.first(ofType: .paragraph))
        XCTAssertEqual(paragraph?.start, 0)
        XCTAssertEqual(paragraph?.end, 12)
    }

    func testMultilineDocumentOffsetsPointIntoSource() {
        let source = "# Title\n\nbody text\n\n- item one"
        let ast = annotate(source)
        let nsSource = source as NSString

        let heading = ast.first(ofType: .heading)?.first(ofType: .text)
        let body = ast.all(ofType: .text).first { $0.content == "body text" }
        guard let headingRange = range(of: heading), let bodyRange = range(of: body) else {
            return XCTFail("expected source ranges")
        }
        XCTAssertEqual(
            nsSource.substring(with: NSRange(location: headingRange.start, length: headingRange.end - headingRange.start)),
            "Title"
        )
        XCTAssertEqual(
            nsSource.substring(with: NSRange(location: bodyRange.start, length: bodyRange.end - bodyRange.start)),
            "body text"
        )
    }

    func testCodeBlockContentMatchesContiguously() {
        let source = "```\nlet a = 1\nlet b = 2\n```"
        let ast = annotate(source)

        guard let code = ast.first(ofType: .codeBlock)?.first(ofType: .text),
              let codeRange = range(of: code) else {
            return XCTFail("expected code text with a range")
        }
        let nsSource = source as NSString
        XCTAssertEqual(
            nsSource.substring(with: NSRange(location: codeRange.start, length: codeRange.end - codeRange.start)),
            "let a = 1\nlet b = 2\n"
        )
    }

    /// A mid-run escape is included in the range: the bytes that produce
    /// "a*b" are the escaped form.
    func testEscapedRunRangeIncludesBackslash() {
        let ast = annotate("a\\*b")

        let text = ast.all(ofType: .text).first { $0.content == "a*b" }
        XCTAssertEqual(range(of: text)?.start, 0)
        XCTAssertEqual(range(of: text)?.end, 4)
    }

    /// Recognized entities never reach the AST (the shared core drops
    /// MD_TEXT_ENTITY), so the text after one must still anchor past the
    /// reference instead of derailing.
    func testDroppedEntityDoesNotDerailFollowingText() {
        let ast = annotate("&copy; 2026")

        let text = ast.all(ofType: .text).first { $0.content == " 2026" }
        XCTAssertEqual(range(of: text)?.start, 6)
        XCTAssertEqual(range(of: text)?.end, 11)
    }

    func testThematicBreakIsAnnotatedStructurally() {
        let ast = annotate("a\n\n---\n\nb")

        let thematicBreak = range(of: ast.first(ofType: .thematicBreak))
        XCTAssertEqual(thematicBreak?.start, 3)
        XCTAssertEqual(thematicBreak?.end, 6)
        let tail = ast.all(ofType: .text).first { $0.content == "b" }
        XCTAssertEqual(range(of: tail)?.start, 8)
    }

    func testNonAsciiOffsetsAreUTF8Bytes() {
        let source = "ż **ó** ł"
        let ast = annotate(source)

        // "ż" is two UTF-8 bytes, so "ó" starts at byte 5 after "ż **".
        let bold = ast.all(ofType: .text).first { $0.content == "ó" }
        XCTAssertEqual(range(of: bold)?.start, 5)
        XCTAssertEqual(range(of: bold)?.end, 7)
    }

    func testEscapedRunKeepsLaterMatchesAnchored() {
        let source = "a\\*b\n\nplain tail"
        let ast = annotate(source)

        let tail = ast.all(ofType: .text).first { $0.content == "plain tail" }
        let tailRange = range(of: tail)
        XCTAssertEqual(tailRange?.start, 6)
        XCTAssertEqual(tailRange?.end, 16)
    }
}
