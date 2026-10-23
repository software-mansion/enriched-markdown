import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownStreaming

final class StreamingMarkdownRepairTests: XCTestCase {
    private func assertRepairs(
        _ cases: [(String, String)],
        syntax: StreamingMarkdownRepair.Syntax = .init(),
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for (input, expected) in cases {
            XCTAssertEqual(
                StreamingMarkdownRepair.repair(input, syntax: syntax),
                expected,
                "repairing \(input.debugDescription)",
                file: file,
                line: line
            )
        }
    }

    func testBold() {
        assertRepairs([
            ("Text with **bold", "Text with **bold**"),
            ("**incomplete", "**incomplete**"),
            ("**first** and **second", "**first** and **second**"),
            ("Here is some **bold tex", "Here is some **bold tex**"),
            ("**xxx*", "**xxx**"),
            ("Text with **bold*", "Text with **bold**"),
            ("**complete**", "**complete**"),
            ("`code` **bold", "`code` **bold**")
        ])
    }

    func testItalic() {
        assertRepairs([
            ("Text with *italic", "Text with *italic*"),
            ("**bold** and *italic", "**bold** and *italic*"),
            ("234234*123", "234234*123"),
            ("hello*world", "hello*world"),
            ("test*123*test", "test*123*test"),
            ("This is *italic", "This is *italic*"),
            ("*word* and more text", "*word* and more text"),
            ("\\*escaped asterisk and *italic", "\\*escaped asterisk and *italic*"),
            ("Text with _italic", "Text with _italic_"),
            ("__bold__ and _italic", "__bold__ and _italic_"),
            ("café_price", "café_price"),
            ("some_variable_name", "some_variable_name"),
            ("Text with _italic\n", "Text with _italic_\n"),
            ("Text with __italic", "Text with __italic__"),
            ("__xxx_", "__xxx__"),
            ("snake__case and more", "snake__case and more")
        ])
    }

    func testBoldItalic() {
        assertRepairs([
            ("***incomplete", "***incomplete***"),
            ("***first*** and ***second", "***first*** and ***second***"),
            ("**bold and *italic***", "**bold and *italic***")
        ])
    }

    func testStrikethroughHighlightAndSpoiler() {
        assertRepairs([
            ("Text with ~~strike", "Text with ~~strike~~"),
            ("~~first~~ and ~~second", "~~first~~ and ~~second~~"),
            ("~~xxx~", "~~xxx~~"),
            ("a ||secret", "a ||secret||"),
            ("a == b", "a == b")
        ])
        assertRepairs([("Mark ==this", "Mark ==this==")], syntax: .init(highlight: true))
    }

    func testInlineCode() {
        assertRepairs([
            ("Text with `code", "Text with `code`"),
            ("To use this function, call `getData(", "To use this function, call `getData(`"),
            ("``double `tick", "``double `tick``"),
            ("`**bold`", "`**bold`"),
            ("\\`not code\\` **bold", "\\`not code\\` **bold**"),
            ("```\nblock\n```\n`inline", "```\nblock\n```\n`inline`")
        ])
    }

    func testNestedClosersCloseInOpeningOrder() {
        assertRepairs([
            ("This is **bold with *ital", "This is **bold with *ital***"),
            ("**bold _und", "**bold _und_**"),
            ("Text **bold `code", "Text **bold `code`**"),
            ("# Main Title\n## Subtitle with **emph", "# Main Title\n## Subtitle with **emph**"),
            ("> Quote with **bold", "> Quote with **bold**")
        ])
    }

    func testFinishedParagraphsAreLeftAlone() {
        assertRepairs([
            ("An **unmatched marker.\n\nNext paragraph", "An **unmatched marker.\n\nNext paragraph"),
            ("- one **x\n- two", "- one **x\n- two"),
            ("- item with **bold", "- item with **bold**")
        ])
    }

    func testTableCellIsItsOwnScope() {
        assertRepairs([
            ("| Col1 | Col2 |\n|------|------|\n| **dat", "| Col1 | Col2 |\n|------|------|\n| **dat**"),
            ("| a **b | c", "| a **b | c")
        ])
    }

    func testOpenFenceIsNotRepaired() {
        let text = "Intro\n\n```swift\nlet x = **y\n"
        assertRepairs([
            (text, text),
            (text + "``", text),
            ("````\ncode\n```", "````\ncode\n")
        ])
    }

    func testClosingFenceEndingTheTextIsKept() {
        let closed = "Intro\n\n```swift\nlet x = 1\n```"
        let quoted = "> ```\n> code\n> ```"
        assertRepairs([
            (closed, closed),
            (quoted, quoted),
            ("~~~\ncode\n~~~", "~~~\ncode\n~~~")
        ])
    }

    func testDelimitersWithoutContentWait() {
        assertRepairs([
            ("Hello **", "Hello"),
            ("Hello *", "Hello"),
            ("Hello `", "Hello"),
            ("** text", "** text"),
            ("a * b", "a * b")
        ])
    }

    func testTrailingMarkerOnlyLineIsHidden() {
        assertRepairs([
            ("Paragraph\n-", "Paragraph\n"),
            ("Paragraph\n--", "Paragraph\n"),
            ("Paragraph\n=", "Paragraph\n"),
            ("Paragraph\n---", "Paragraph\n---"),
            ("Intro\n\n#", "Intro\n\n"),
            ("Intro\n\n## ", "Intro\n\n"),
            ("- one\n- ", "- one\n"),
            ("1. one\n2.", "1. one\n"),
            ("Intro\n\n``", "Intro\n\n"),
            ("> quote\n>", "> quote\n"),
            ("Price\n12", "Price\n12")
        ])
    }

    func testHalfWrittenAdmonitionMarkerIsHidden() {
        assertRepairs([
            ("Intro\n\n> [!", "Intro\n\n"),
            ("Intro\n\n> [!NO", "Intro\n\n"),
            ("Intro\n\n> [!NOTE]", "Intro\n\n> [!NOTE]"),
            ("Intro\n\n> [!NOTE]\n> Body", "Intro\n\n> [!NOTE]\n> Body"),
            ("See [!important", "See !important")
        ])
    }

    func testIncompleteLinksShowTheirText() {
        assertRepairs([
            ("Text with [incomplete link", "Text with incomplete link"),
            ("Visit [our site](https://exa", "Visit our site"),
            ("[outer [nested] text](incomplete", "outer [nested] text"),
            ("Text [foo [bar] baz](", "Text foo [bar] baz"),
            ("See [docs]", "See docs"),
            ("A [link](https://x.y) done", "A [link](https://x.y) done"),
            ("[**bold link", "**bold link**")
        ])
    }

    func testIncompleteImagesAreHidden() {
        assertRepairs([
            ("Text ![incomplete image", "Text"),
            ("Text ![alt](http://partial", "Text"),
            ("Text ![alt]", "Text")
        ])
    }

    func testTaskCheckboxIsNotALink() {
        assertRepairs([
            ("- [ ]", "- [ ]"),
            ("- [x]", "- [x]")
        ])
    }

    func testUnclosedMathIsHiddenUntilItCloses() {
        let latex = StreamingMarkdownRepair.Syntax(latexMath: true)
        assertRepairs([
            ("The area is $\\pi r^", "The area is"),
            ("Closed $x^2$ and open $\\frac{1}", "Closed $x^2$ and open"),
            ("Display $$\\sum_i", "Display"),
            ("Done: $a_1$.", "Done: $a_1$.")
        ], syntax: latex)
    }

    func testPricesAreNotMath() {
        let latex = StreamingMarkdownRepair.Syntax(latexMath: true)
        assertRepairs([
            ("Das kostet 5$ und mehr", "Das kostet 5$ und mehr"),
            ("Das kostet 5 $ pro Stück", "Das kostet 5 $ pro Stück"),
            ("It costs $5 and", "It costs $5 and"),
            ("Für 3$ bekommst du **viel", "Für 3$ bekommst du **viel**")
        ], syntax: latex)
    }

    func testMathIsLiteralWithoutTheLaTeXPlugin() {
        assertRepairs([("The area is $\\pi r^", "The area is $\\pi r^")])
    }

    func testUnderscoresInMathAreNotEmphasis() {
        assertRepairs(
            [("Let $a_1 + b_2$ be _small", "Let $a_1 + b_2$ be _small_")],
            syntax: .init(latexMath: true)
        )
    }

    func testSyntaxFollowsTheParsingOptions() {
        var options = MarkdownParsingOptions(highlight: true)
        XCTAssertEqual(StreamingMarkdownRepair.Syntax(options: options), .init(latexMath: false, highlight: true))
        options.latexMathEnabled = true
        XCTAssertEqual(StreamingMarkdownRepair.Syntax(options: options), .init(latexMath: true, highlight: true))
    }

    func testRepairKeepsFinishedText() {
        let answer = "Here is a **bold statement** about `code` and [a link](https://example.com)."
        for length in 1...answer.count {
            let prefix = String(answer.prefix(length))
            let repaired = StreamingMarkdownRepair.repair(prefix)
            let stable = prefix.prefix(while: { $0 != "*" && $0 != "`" && $0 != "[" })
            XCTAssertTrue(repaired.hasPrefix(stable.trimmingCharacters(in: .whitespaces)), prefix)
        }
        XCTAssertEqual(StreamingMarkdownRepair.repair(answer), answer)
    }
}
