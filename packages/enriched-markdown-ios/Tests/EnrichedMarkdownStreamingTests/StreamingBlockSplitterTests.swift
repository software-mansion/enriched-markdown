import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownStreaming

final class StreamingBlockSplitterTests: XCTestCase {
    private func scan(_ markdown: String) -> StreamingBlockSplitter.Scan {
        StreamingBlockSplitter.scan(Array(markdown.utf8))
    }

    private func lastCut(_ markdown: String) -> String? {
        scan(markdown).lastCut.flatMap { String(bytes: Array(markdown.utf8)[$0.offset...], encoding: .utf8) }
    }

    private func lastBlockCut(_ markdown: String) -> String? {
        scan(markdown).lastBlockCut.flatMap { String(bytes: Array(markdown.utf8)[$0.offset...], encoding: .utf8) }
    }

    private func continuesList(_ markdown: String) -> Bool? {
        scan(markdown).lastCut?.continuesList
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
        XCTAssertNil(lastCut("1. one\n\n2"))
        XCTAssertNil(lastCut("- one\n\n  continued"))
        XCTAssertNil(lastCut("Para\n\n    indented code"))
        XCTAssertNil(lastCut("- one\nlazy continuation"))
        XCTAssertEqual(lastCut("- one\n\nAfter the list"), "After the list")
        XCTAssertEqual(continuesList("- one\n\nAfter the list"), false)
    }

    func testCutsBetweenTheItemsOfOneList() {
        XCTAssertEqual(lastCut("- one\n- two"), "- two")
        XCTAssertEqual(continuesList("- one\n- two"), true)
        XCTAssertEqual(lastCut("- one\n\n- two"), "- two")
        XCTAssertEqual(continuesList("- one\n\n- two"), true)
        XCTAssertEqual(lastCut("1. one\n2. two\n3. three"), "3. three")
        XCTAssertEqual(lastCut("- one\n  - nested\n- two"), "- two")
        XCTAssertEqual(lastCut("- one\nlazy\n- two"), "- two")
        XCTAssertEqual(lastCut("- [x] one\n- [ ] two"), "- [ ] two")
        XCTAssertNil(lastBlockCut("- one\n- two"))
    }

    func testAListStartsANewBlockOnlyAfterABlankLine() {
        XCTAssertEqual(lastCut("Para\n\n- one"), "- one")
        XCTAssertEqual(continuesList("Para\n\n- one"), false)
        XCTAssertEqual(lastBlockCut("Para\n\n- one\n- two"), "- one\n- two")
        XCTAssertNil(lastCut("Para\n- one"))
    }

    func testADifferentMarkerStartsAnotherList() {
        XCTAssertNil(lastCut("- one\n* two"))
        XCTAssertEqual(continuesList("- one\n\n* two"), false)
        XCTAssertNil(lastCut("1. one\n1) two"))
        XCTAssertNil(lastCut("* one\n* * *"))
    }

    func testMarkerLinesInsideFencesAndHTMLBlocksAreNotItems() {
        XCTAssertNil(lastCut("- one\n```\ncode\n- two"))
        XCTAssertNil(lastCut("- one\n<div>\n- two\n- three"))
        XCTAssertEqual(lastCut("- one\n<div>\n- two\n\n- three"), "- three")
        XCTAssertEqual(continuesList("- one\n<div>\n- two\n\n- three"), false)
    }

    func testReportsATopLevelOpenFence() {
        let open = scan("Para\n\n```swift\nlet x")
        XCTAssertEqual(open.openFence, StreamingBlockSplitter.OpenFence(start: 6, character: UInt8(ascii: "`"), length: 3))
        XCTAssertEqual(scan("~~~~\ncode").openFence?.length, 4)
        XCTAssertNil(scan("- item\n\n  ```swift\n  let x").openFence)
        XCTAssertNil(scan("> ```\n> code").openFence)
        XCTAssertNil(scan("```\ncode\n```").openFence)
    }

    func testNoCutInsideAFence() {
        XCTAssertNil(lastCut("```\ncode\n\nmore code"))
        XCTAssertEqual(lastCut("```\ncode\n\nmore\n```\n\nAfter"), "After")
    }

    func testFenceClosesOnlyOnALongEnoughBareRun() {
        XCTAssertNil(lastCut("```\ncode\n``` info\n\nAfter"))
        XCTAssertNil(lastCut("````\ncode\n```\n\nAfter"))
        XCTAssertNil(lastCut("~~~\ncode\n```\n\nAfter"))
        XCTAssertEqual(lastCut("~~~\ncode\n~~~\n\nAfter"), "After")
        XCTAssertEqual(lastCut("> ```\n> code\n> ```\n\nAfter"), "After")
    }

    func testRawHTMLStopsCutting() {
        XCTAssertEqual(lastCut("A\n\nB\n\n<!-- note\n\nC"), "B\n\n<!-- note\n\nC")
    }

    func testLinkReferenceDefinitionIsReported() {
        XCTAssertTrue(scan("See [x].\n\n[x]: https://example.com").hasLinkReferenceDefinition)
        XCTAssertFalse(scan("See [x](https://example.com).").hasLinkReferenceDefinition)
    }
}
