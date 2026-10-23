import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownStreaming

final class StreamingMarkdownFilterTests: XCTestCase {
    private func filter(
        _ markdown: String,
        tables: MarkdownStreamingOptions.TableMode = .progressive,
        codeBlocks: MarkdownStreamingOptions.CodeBlockMode = .progressive,
        latexMath: Bool = false
    ) -> String {
        StreamingMarkdownFilter.renderable(
            markdown,
            openFenceStart: StreamingBlockSplitter.scan(Array(markdown.utf8)).openFenceStart,
            options: MarkdownStreamingOptions(tables: tables, codeBlocks: codeBlocks),
            latexMath: latexMath
        )
    }

    func testProgressiveTableWaitsForItsDelimiterRow() {
        XCTAssertEqual(filter("Intro\n\n| A | B |"), "Intro\n\n")
        XCTAssertEqual(filter("Intro\n\n| A | B |\n|--"), "Intro\n\n")
        XCTAssertEqual(filter("Intro\n\n| A | B |\n|---|---|"), "Intro\n\n| A | B |\n|---|---|")
    }

    func testProgressiveTableHoldsBackAHalfWrittenRow() {
        let table = "| A | B |\n|---|---|\n| 1 | 2 |\n"
        XCTAssertEqual(filter(table + "| 3 |"), table)
        XCTAssertEqual(filter(table + "| 3 | 4"), table)
        XCTAssertEqual(filter(table + "| 3 | 4 |"), table + "| 3 | 4 |")
    }

    func testHiddenTableWaitsForABlankLine() {
        let table = "| A | B |\n|---|---|\n| 1 | 2 |"
        XCTAssertEqual(filter("Intro\n\n" + table, tables: .hidden), "Intro\n\n")
        XCTAssertEqual(filter("Intro\n\n" + table + "\n", tables: .hidden), "Intro\n\n")
        XCTAssertEqual(filter("Intro\n\n" + table + "\n\n", tables: .hidden), "Intro\n\n" + table + "\n\n")
    }

    func testNonTableTailIsKept() {
        XCTAssertEqual(filter("Just a paragraph | with a pipe"), "Just a paragraph | with a pipe")
    }

    func testProgressiveCodeBlockStreams() {
        let markdown = "Intro\n\n```swift\nlet x = 1\n"
        XCTAssertEqual(filter(markdown), markdown)
    }

    func testHiddenCodeBlockWaitsForItsClosingFence() {
        XCTAssertEqual(filter("Intro\n\n```swift\nlet x = 1\n", codeBlocks: .hidden), "Intro\n\n")
        let closed = "Intro\n\n```swift\nlet x = 1\n```"
        XCTAssertEqual(filter(closed, codeBlocks: .hidden), closed)
    }

    func testFenceClosesOnlyOnALongEnoughBareRun() {
        let markdown = "````\ncode\n```\nstill code"
        XCTAssertEqual(filter(markdown, codeBlocks: .hidden), "")
        XCTAssertEqual(filter("~~~\ncode\n```\n", codeBlocks: .hidden), "")
        XCTAssertEqual(filter("```\ncode\n``` info\n", codeBlocks: .hidden), "")
    }

    func testTableInsideOpenCodeBlockIsCode() {
        let markdown = "```\n| A |\n"
        XCTAssertEqual(filter(markdown), markdown)
    }

    func testBlockMathIsAllOrNothing() {
        XCTAssertEqual(filter("Intro\n\n$$\nx^2 +", latexMath: true), "Intro\n\n")
        let closed = "Intro\n\n$$\nx^2\n$$"
        XCTAssertEqual(filter(closed, latexMath: true), closed)
    }

    func testDollarLinesAreTextWithoutLaTeX() {
        XCTAssertEqual(filter("Intro\n\n$$\nx^2 +"), "Intro\n\n$$\nx^2 +")
    }
}
