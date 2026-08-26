import UIKit
import XCTest
@testable import EnrichedMarkdown

final class MarkdownExtractorTests: XCTestCase {
    private var config: MarkdownStyleConfig!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.baseline()
    }

    // MARK: - Helpers

    private func render(_ markdown: String, flags: Md4cFlags = .commonMark) -> NSAttributedString {
        MarkdownRenderer.render(markdown, config: config, flags: flags)
    }

    private func extractSelecting(
        _ substring: String,
        in markdown: String,
        flags: Md4cFlags = .commonMark,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> String? {
        let rendered = render(markdown, flags: flags)
        let range = (rendered.string as NSString).range(of: substring)
        XCTAssertNotEqual(
            range.location, NSNotFound,
            "substring '\(substring)' not found in rendered output '\(rendered.string)'",
            file: file, line: line
        )
        guard range.location != NSNotFound else { return nil }
        return MarkdownExtractor.extractMarkdown(from: rendered, in: range)
    }

    private func extractFullRange(_ markdown: String, flags: Md4cFlags = .commonMark) -> String? {
        let rendered = render(markdown, flags: flags)
        return MarkdownExtractor.extractMarkdown(
            from: rendered,
            in: NSRange(location: 0, length: rendered.length)
        )
    }

    // MARK: - Invalid input

    func testReturnsNilForEmptyRange() {
        let rendered = render("Hello")
        XCTAssertNil(MarkdownExtractor.extractMarkdown(from: rendered, in: NSRange(location: 2, length: 0)))
    }

    func testReturnsNilForOutOfBoundsRange() {
        let rendered = render("Hello")
        XCTAssertNil(
            MarkdownExtractor.extractMarkdown(
                from: rendered,
                in: NSRange(location: rendered.length + 5, length: 3)
            )
        )
    }

    // MARK: - Full selection

    func testFullSelectionReturnsSourceMarkdownVerbatim() {
        let source = "# Title\n\nParagraph with **bold**."
        let rendered = render(source)

        let markdown = MarkdownExtractor.markdown(
            for: NSRange(location: 0, length: rendered.length),
            in: rendered,
            sourceMarkdown: source
        )

        XCTAssertEqual(markdown, source)
    }

    func testFullSelectionToleratesExcludedTrailingSpacers() {
        let source = "# Title\n\nParagraph with **bold**."
        let rendered = render(source)

        let markdown = MarkdownExtractor.markdown(
            for: NSRange(location: 0, length: rendered.length - 1),
            in: rendered,
            sourceMarkdown: source
        )

        XCTAssertEqual(markdown, source)
    }

    func testPartialSelectionDoesNotReturnSourceMarkdown() {
        let source = "First paragraph.\n\nSecond paragraph."
        let rendered = render(source)
        let range = (rendered.string as NSString).range(of: "Second paragraph.")

        let markdown = MarkdownExtractor.markdown(for: range, in: rendered, sourceMarkdown: source)

        XCTAssertEqual(markdown, "Second paragraph.")
    }

    // MARK: - Inline elements

    func testExtractsPlainParagraphText() {
        XCTAssertEqual(extractSelecting("Hello CommonMark", in: "Hello CommonMark"), "Hello CommonMark")
    }

    func testExtractsPartialSelectionWithinParagraph() {
        XCTAssertEqual(extractSelecting("Hello", in: "Hello world"), "Hello")
    }

    func testExtractsBoldText() {
        XCTAssertEqual(extractSelecting("31%", in: "Forests cover **31%** of land."), "**31%**")
    }

    func testExtractsItalicText() {
        XCTAssertEqual(
            extractSelecting("300 million years", in: "Over *300 million years* old."),
            "*300 million years*"
        )
    }

    func testExtractsBoldAndItalicInSameParagraph() {
        XCTAssertEqual(
            extractSelecting(
                "Text with bold and italic styles.",
                in: "Text with **bold** and *italic* styles."
            ),
            "Text with **bold** and *italic* styles."
        )
    }

    func testExtractsInlineCode() {
        XCTAssertEqual(extractSelecting("48 pounds", in: "Use `48 pounds` per year."), "`48 pounds`")
    }

    func testExtractsLink() {
        XCTAssertEqual(
            extractSelecting("Example link", in: "[Example link](https://example.com)"),
            "[Example link](https://example.com)"
        )
    }

    func testExtractsStrikethrough() {
        XCTAssertEqual(extractSelecting("old value", in: "Price: ~~old value~~ new."), "~~old value~~")
    }

    func testExtractsUnderline() {
        XCTAssertEqual(
            extractSelecting(
                "underlined",
                in: "Some _underlined_ text.",
                flags: Md4cFlags(underline: true)
            ),
            "<u>underlined</u>"
        )
    }

    func testLinkIsNotWrappedInUnderline() {
        XCTAssertEqual(
            extractSelecting("swmansion", in: "Visit [swmansion](https://swmansion.com) now."),
            "[swmansion](https://swmansion.com)"
        )
    }

    // MARK: - Headings

    func testExtractsHeading() {
        XCTAssertEqual(
            extractSelecting(
                "The Hidden World of Forest Ecosystems",
                in: "# The Hidden World of Forest Ecosystems"
            ),
            "# The Hidden World of Forest Ecosystems\n"
        )
    }

    func testExtractsAllHeadingLevels() {
        for level in 1...6 {
            let title = "Heading level \(level)"
            let expected = String(repeating: "#", count: level) + " " + title + "\n"
            let source = String(repeating: "#", count: level) + " " + title
            XCTAssertEqual(extractSelecting(title, in: source), expected)
        }
    }

    func testHeadingAttributeAppliedByRenderer() {
        let rendered = render("# Hi")
        let textRange = (rendered.string as NSString).range(of: "Hi")

        let level = MarkdownAttributeValue.intValue(
            from: rendered.attribute(MarkdownAttribute.headingLevel, at: textRange.location, effectiveRange: nil)
        )

        XCTAssertEqual(level, 1)
    }

    // MARK: - Blockquotes

    func testExtractsBlockquote() {
        let quote = "In every walk with nature, one receives far more than he seeks."
        XCTAssertEqual(extractSelecting(quote, in: "> \(quote)"), "> \(quote)")
    }

    func testExtractsNestedBlockquote() {
        XCTAssertEqual(
            extractSelecting("Inner quote", in: "> Outer quote\n>\n> > Inner quote"),
            "> > Inner quote"
        )
    }

    func testExtractsBlockquoteWithFormattedText() {
        XCTAssertEqual(
            extractSelecting("Quote with bold text.", in: "> Quote with **bold** text."),
            "> Quote with **bold** text."
        )
    }

    // MARK: - Lists

    func testExtractsUnorderedListItem() {
        XCTAssertEqual(
            extractSelecting("Climate regulation", in: "- Climate regulation\n- Biodiversity"),
            "- Climate regulation"
        )
    }

    func testExtractsOrderedListItem() {
        XCTAssertEqual(
            extractSelecting("First item", in: "1. First item\n2. Second item"),
            "1. First item"
        )
    }

    func testExtractsSecondOrderedListItem() {
        XCTAssertEqual(
            extractSelecting("Second item", in: "1. First item\n2. Second item"),
            "2. Second item"
        )
    }

    func testExtractsNestedUnorderedListItem() {
        XCTAssertEqual(
            extractSelecting("Nested item", in: "- Parent item\n  - Nested item"),
            "  - Nested item"
        )
    }

    func testExtractsMultipleListItems() {
        let rendered = render("- Alpha\n- Beta")
        let string = rendered.string as NSString
        let start = string.range(of: "Alpha")
        let end = string.range(of: "Beta")
        let range = NSRange(location: start.location, length: NSMaxRange(end) - start.location)

        XCTAssertEqual(
            MarkdownExtractor.extractMarkdown(from: rendered, in: range),
            "- Alpha\n- Beta"
        )
    }

    // MARK: - Code blocks

    func testExtractsMultiLineCodeBlock() {
        let code = "func main() {\n  print(\"forest\")\n}\n"
        let rendered = render("```\nfunc main() {\n  print(\"forest\")\n}\n```")
        let range = (rendered.string as NSString).range(of: code)
        XCTAssertNotEqual(range.location, NSNotFound)

        XCTAssertEqual(
            MarkdownExtractor.extractMarkdown(from: rendered, in: range),
            "```\n\(code)```\n"
        )
    }

    func testExtractsCodeBlockWithoutClosingFenceWhenSelectionExcludesTrailingNewline() {
        let code = "let answer = 42"
        XCTAssertEqual(
            extractSelecting(code, in: "```\nlet answer = 42\n```"),
            "```\n\(code)"
        )
    }

    // MARK: - Thematic breaks and images

    func testExtractsThematicBreak() {
        let rendered = render("Before\n\n---\n\nAfter")
        let breakLocation = (rendered.string as NSString).range(of: "\u{FFFC}")
        XCTAssertNotEqual(breakLocation.location, NSNotFound)

        XCTAssertEqual(
            MarkdownExtractor.extractMarkdown(from: rendered, in: breakLocation),
            "---\n"
        )
    }

    func testExtractsInlineImage() {
        let url = "https://example.com/forest.jpg"
        let rendered = render("Before ![image](\(url)) after")
        let imageLocation = (rendered.string as NSString).range(of: "\u{FFFC}")
        XCTAssertNotEqual(imageLocation.location, NSNotFound)

        XCTAssertEqual(
            MarkdownExtractor.extractMarkdown(from: rendered, in: imageLocation),
            "![image](\(url))"
        )
    }

    func testExtractsBlockImage() {
        let url = "https://example.com/forest.jpg"
        let rendered = render("![image](\(url))")
        let imageLocation = (rendered.string as NSString).range(of: "\u{FFFC}")
        XCTAssertNotEqual(imageLocation.location, NSNotFound)

        XCTAssertEqual(
            MarkdownExtractor.extractMarkdown(from: rendered, in: imageLocation),
            "![image](\(url))\n"
        )
    }

    func testExtractsParagraphWithInlineImageAndText() {
        let url = "https://example.com/forest.jpg"
        let rendered = render("See ![image](\(url)) for details.")
        let string = rendered.string as NSString
        let start = string.range(of: "See ")
        let end = string.range(of: " for details.")
        let range = NSRange(location: start.location, length: NSMaxRange(end) - start.location)

        XCTAssertEqual(
            MarkdownExtractor.extractMarkdown(from: rendered, in: range),
            "See ![image](\(url)) for details."
        )
    }

    // MARK: - Line breaks

    func testSoftBreakExtractsAsSpace() {
        XCTAssertEqual(extractSelecting("alpha beta", in: "alpha\nbeta"), "alpha beta")
    }

    func testHardBreakExtractsAsNewline() {
        let extracted = extractFullRange("line one  \nline two")
        XCTAssertNotNil(extracted)
        XCTAssertTrue(
            extracted?.contains("line one\nline two") ?? false,
            "expected hard break as newline in '\(extracted ?? "nil")'"
        )
    }

    // MARK: - Image URLs

    func testImageURLsReturnsHttpUrlsInRange() {
        let url = "https://example.com/forest.jpg"
        let rendered = render("![image](\(url))")

        XCTAssertEqual(
            MarkdownExtractor.imageURLs(in: rendered, range: NSRange(location: 0, length: rendered.length)),
            [url]
        )
    }

    func testImageURLsFiltersNonHttpSchemes() {
        let rendered = render("![image](file:///tmp/local.png)")

        XCTAssertEqual(
            MarkdownExtractor.imageURLs(in: rendered, range: NSRange(location: 0, length: rendered.length)),
            []
        )
    }

    func testImageURLsReturnsEmptyForEmptyRange() {
        let rendered = render("![image](https://example.com/forest.jpg)")

        XCTAssertEqual(
            MarkdownExtractor.imageURLs(in: rendered, range: NSRange(location: 0, length: 0)),
            []
        )
    }
}
