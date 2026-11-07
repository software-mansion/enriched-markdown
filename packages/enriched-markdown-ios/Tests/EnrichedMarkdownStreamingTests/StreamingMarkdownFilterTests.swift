import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownStreaming

final class StreamingMarkdownFilterTests: XCTestCase {
    private func filter(
        _ markdown: String,
        tables: MarkdownStreamingOptions.TableMode = .progressive,
        codeBlocks: MarkdownStreamingOptions.CodeBlockMode = .progressive
    ) -> StreamingMarkdownFilter.Result {
        StreamingMarkdownFilter.renderable(markdown, options: MarkdownStreamingOptions(tables: tables, codeBlocks: codeBlocks))
    }

    func testTablesFollowTheTableMode() {
        let table = "Intro\n\n| A | B |\n|---|---|\n| 1 | 2 |"
        XCTAssertEqual(filter(table + "\n| 3 |").markdown, table + "\n")
        XCTAssertEqual(filter(table, tables: .hidden).markdown, "Intro\n\n")
        XCTAssertEqual(filter(table + "\n\n", tables: .hidden).markdown, table + "\n\n")
    }

    func testCodeBlocksFollowTheCodeBlockMode() {
        let open = "Intro\n\n```swift\nlet x = 1\n"
        let progressive = filter(open)
        XCTAssertEqual(progressive.markdown, open)
        XCTAssertTrue(progressive.endsInsideOpenCodeFence)
        let hidden = filter(open, codeBlocks: .hidden)
        XCTAssertEqual(hidden.markdown, "Intro\n\n")
        XCTAssertFalse(hidden.endsInsideOpenCodeFence)
        XCTAssertFalse(filter(open + "```\n").endsInsideOpenCodeFence)
    }

    func testOpenMathBlockWaitsForItsClosingDelimiter() {
        XCTAssertEqual(filter("Intro\n\n$$\nx^2 +").markdown, "Intro\n\n")
        XCTAssertEqual(filter("Intro\n\n$$\nx^2\n$$").markdown, "Intro\n\n$$\nx^2\n$$")
    }

    func testOpenLinkOrImageIsWithheld() {
        XCTAssertEqual(filter("See ![leaf](https://e").markdown, "See ")
        XCTAssertEqual(filter("See [docs]").markdown, "See ")
        XCTAssertEqual(filter("See [docs](https://e.com) now").markdown, "See [docs](https://e.com) now")
    }

    func testFinishedTextIsUnchanged() {
        let markdown = "Just a paragraph | with a pipe"
        XCTAssertEqual(filter(markdown).markdown, markdown)
    }
}
