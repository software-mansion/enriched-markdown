import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownStreaming

final class StreamingBlockSplitterTests: XCTestCase {
    private func scan(_ markdown: String) -> StreamingBlockSplitter.Scan {
        StreamingBlockSplitter.scan(Array(markdown.utf8))
    }

    private func lastCut(_ markdown: String) -> String? {
        scan(markdown).lastCut.flatMap { String(bytes: Array(markdown.utf8)[$0...], encoding: .utf8) }
    }

    func testCutsBeforeABlockAfterABlankLine() {
        XCTAssertEqual(lastCut("# Title\n\nFirst paragraph.\n\nSecond"), "Second")
        XCTAssertEqual(lastCut("Para\n\n| A |"), "| A |")
        XCTAssertEqual(lastCut("Para\n\n```swift\ncode"), "```swift\ncode")
    }

    func testNoCutWithoutABlankLine() {
        XCTAssertNil(lastCut("Line one\nLine two"))
        XCTAssertNil(lastCut("Only a paragraph"))
    }

    func testNoCutBeforeWhatMayContinueTheBlockBefore() {
        XCTAssertNil(lastCut("- one\n\n- two"))
        XCTAssertNil(lastCut("1. one\n\n2"))
        XCTAssertNil(lastCut("- one\n\n  continued"))
        XCTAssertNil(lastCut("Para\n\n    indented code"))
        XCTAssertEqual(lastCut("- one\n\nAfter the list"), "After the list")
    }

    func testNoCutInsideAFence() {
        XCTAssertNil(lastCut("```\ncode\n\nmore code"))
        XCTAssertEqual(lastCut("```\ncode\n\nmore\n```\n\nAfter"), "After")
    }

    func testOpenFenceStartIsItsLineStart() {
        XCTAssertEqual(scan("Para\n\n```swift\ncode").openFenceStart, 6)
        XCTAssertEqual(scan("- item\n\n  ```\n  code").openFenceStart, 8)
        XCTAssertEqual(scan("> ```\n> code").openFenceStart, 0)
        XCTAssertEqual(scan("```\ncode\n``` info\n").openFenceStart, 0)
        XCTAssertEqual(scan("````\ncode\n```\n").openFenceStart, 0)
        XCTAssertNil(scan("```\ncode\n```").openFenceStart)
        XCTAssertNil(scan("~~~\ncode\n~~~\n\nAfter").openFenceStart)
    }

    func testRawHTMLStopsCutting() {
        XCTAssertEqual(lastCut("A\n\nB\n\n<!-- note\n\nC"), "B\n\n<!-- note\n\nC")
    }

    func testLinkReferenceDefinitionIsReported() {
        XCTAssertTrue(scan("See [x].\n\n[x]: https://example.com").hasLinkReferenceDefinition)
        XCTAssertFalse(scan("See [x](https://example.com).").hasLinkReferenceDefinition)
    }
}
