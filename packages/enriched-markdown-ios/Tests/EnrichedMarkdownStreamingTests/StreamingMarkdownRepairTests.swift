import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownStreaming

final class StreamingMarkdownRepairTests: XCTestCase {
    private static let latex: MarkdownParsingOptions = {
        var options = MarkdownParsingOptions()
        options.latexMathEnabled = true
        return options
    }()

    private func assertRepairs(
        _ cases: [(String, String)],
        options: MarkdownParsingOptions = MarkdownParsingOptions(),
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for (input, expected) in cases {
            XCTAssertEqual(
                StreamingMarkdownRepair.repair(input, options: options),
                expected,
                "repairing \(input.debugDescription)",
                file: file,
                line: line
            )
        }
    }

    func testOpenSyntaxIsClosed() {
        assertRepairs([
            ("Text with **bold", "Text with **bold**"),
            ("This is **bold with *ital", "This is **bold with *ital***"),
            ("Text **bold `code", "Text **bold `code`**"),
            ("a ||secret", "a ||secret||"),
            ("**bold** and *italic  ", "**bold** and *italic*  ")
        ])
    }

    func testIncompleteLinksShowTheirText() {
        assertRepairs([
            ("Visit [our site](https://exa", "Visit our site"),
            ("Text with [incomplete link", "Text with incomplete link"),
            ("See [docs]", "See [docs]"),
            ("Text ![alt](http://partial", "Text ")
        ])
    }

    func testHalfWrittenSyntaxIsWithheld() {
        assertRepairs([
            ("Hello **", "Hello"),
            ("Intro\n\n```swift\nlet x = **y\n``", "Intro\n\n```swift\nlet x = **y\n"),
            ("- one\n- ", "- one\n"),
            ("- [x] done\n- [x", "- [x] done\n"),
            ("Intro\n\n> [!NO", "Intro\n\n"),
            ("Paragraph\n--", "Paragraph\n")
        ])
    }

    func testHighlightFollowsTheParserOption() {
        assertRepairs([("Mark ==this", "Mark ==this")])
        assertRepairs([("Mark ==this", "Mark ==this==")], options: MarkdownParsingOptions(highlight: true))
    }

    func testCaretsAndTildesAreNotClosed() {
        assertRepairs([("x^2 and **b", "x^2 and **b**")], options: MarkdownParsingOptions(superscript: true))
        assertRepairs([("H~2 and **b", "H\\~2 and **b**")], options: MarkdownParsingOptions(subscript: true))
    }

    func testUnclosedMathFollowsTheLaTeXOption() {
        assertRepairs([
            ("The area is $\\pi r^", "The area is"),
            ("Display $$\\sum_i", "Display"),
            ("It costs $5 and", "It costs $5 and")
        ], options: Self.latex)
        assertRepairs([
            ("The area is $\\pi r^", "The area is $\\pi r^"),
            ("Display $$\\sum_i", "Display $$\\sum_i")
        ])
    }

    func testRepairKeepsFinishedText() {
        let answer = "Here is a **bold statement** about `code` and [a link](https://example.com)."
        for length in 1...answer.count {
            let prefix = String(answer.prefix(length))
            let repaired = StreamingMarkdownRepair.repair(prefix, options: MarkdownParsingOptions())
            let stable = prefix.prefix(while: { $0 != "*" && $0 != "`" && $0 != "[" })
            XCTAssertTrue(repaired.hasPrefix(stable.trimmingCharacters(in: .whitespaces)), prefix)
        }
        XCTAssertEqual(StreamingMarkdownRepair.repair(answer, options: MarkdownParsingOptions()), answer)
    }
}
