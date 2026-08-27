import UIKit
import XCTest
@testable import EnrichedMarkdown

final class MarkdownSourceSlicerTests: XCTestCase {
    private var config: MarkdownStyleConfig!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.baseline()
    }

    /// Copy-as-Markdown result for the rendered selection matching
    /// `substring`, with the source available for slicing.
    private func copyMarkdown(
        selecting substring: String,
        in source: String,
        flags: Md4cFlags = .commonMark,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> String? {
        let rendered = MarkdownRenderer.render(source, config: config, flags: flags)
        let range = (rendered.string as NSString).range(of: substring)
        XCTAssertNotEqual(
            range.location, NSNotFound,
            "substring '\(substring)' not found in rendered output '\(rendered.string)'",
            file: file, line: line
        )
        guard range.location != NSNotFound else { return nil }
        return MarkdownExtractor.markdown(for: range, in: rendered, sourceMarkdown: source, flags: flags)
    }

    // MARK: - Verbatim slices

    func testParagraphSubstringIsSlicedVerbatim() {
        XCTAssertEqual(
            copyMarkdown(selecting: "second paragraph", in: "first paragraph\n\nsecond paragraph"),
            "second paragraph"
        )
    }

    func testFullySelectedBoldKeepsItsMarkers() {
        XCTAssertEqual(
            copyMarkdown(selecting: "bold", in: "hello **bold** world"),
            "**bold**"
        )
    }

    func testBoldWithTailKeepsInteriorMarkers() {
        XCTAssertEqual(
            copyMarkdown(selecting: "bold world", in: "hello **bold** world"),
            "**bold** world"
        )
    }

    func testFullySelectedLinkKeepsLabelAndDestination() {
        XCTAssertEqual(
            copyMarkdown(selecting: "docs", in: "see [docs](https://x.com) now"),
            "[docs](https://x.com)"
        )
    }

    func testLinkWithTailKeepsInteriorDestination() {
        XCTAssertEqual(
            copyMarkdown(selecting: "docs now", in: "see [docs](https://x.com) now"),
            "[docs](https://x.com) now"
        )
    }

    func testFullySelectedInlineCodeKeepsBackticks() {
        XCTAssertEqual(
            copyMarkdown(selecting: "let", in: "use `let` here"),
            "`let`"
        )
    }

    func testFullySelectedStrikethroughKeepsMarkers() {
        XCTAssertEqual(
            copyMarkdown(selecting: "gone", in: "some ~~gone~~ text"),
            "~~gone~~"
        )
    }

    func testSoftBreakSurvivesAsSourceNewline() {
        XCTAssertEqual(
            copyMarkdown(selecting: "one line", in: "line one\nline two"),
            "one\nline"
        )
    }

    func testNonAsciiSelectionSlicesOnByteBoundaries() {
        XCTAssertEqual(
            copyMarkdown(selecting: "gęślą jaźń", in: "zażółć **gęślą** jaźń"),
            "**gęślą** jaźń"
        )
    }

    // MARK: - Block prefixes

    func testListItemSelectionIncludesItsMarker() {
        XCTAssertEqual(
            copyMarkdown(selecting: "two", in: "- one\n- two"),
            "- two"
        )
    }

    func testMultiItemSelectionIsSlicedVerbatim() {
        XCTAssertEqual(
            copyMarkdown(selecting: "one\ntwo", in: "- one\n- two"),
            "- one\n- two"
        )
    }

    func testTaskItemSelectionIncludesMarkerAndBox() {
        XCTAssertEqual(
            copyMarkdown(selecting: "done", in: "- [x] done\n- [ ] later"),
            "- [x] done"
        )
    }

    func testBlockquoteSelectionIncludesItsBar() {
        XCTAssertEqual(
            copyMarkdown(selecting: "quoted words", in: "intro\n\n> quoted words"),
            "> quoted words"
        )
    }

    func testHeadingSelectionKeepsHashesAndInlineMarkers() {
        XCTAssertEqual(
            copyMarkdown(selecting: "Big deal", in: "intro\n\n# Big **deal**"),
            "# Big **deal**"
        )
    }

    func testFullySelectedCodeBlockIncludesFences() {
        XCTAssertEqual(
            copyMarkdown(selecting: "let a = 1\n", in: "intro\n\n```\nlet a = 1\n```"),
            "```\nlet a = 1\n```"
        )
    }

    // MARK: - Fallback to reconstruction

    func testMidMarkerCutFallsBackToReconstruction() {
        XCTAssertEqual(
            copyMarkdown(selecting: "old wor", in: "hello **bold** world"),
            "**old** wor"
        )
    }

    func testEscapedTextSlicesWithItsEscapes() {
        XCTAssertEqual(
            copyMarkdown(selecting: "a*b and", in: "a\\*b and more\n\nplain"),
            "a\\*b and"
        )
    }

    func testBareAmpersandTextSlicesVerbatim() {
        XCTAssertEqual(
            copyMarkdown(selecting: "AT&T stays", in: "AT&T stays here\n\ntail"),
            "AT&T stays"
        )
    }

    func testEscapedPrefixKeepsLaterSlicesAnchored() {
        let source = "x\\*b\n\nb\n\nZZZ"
        let rendered = MarkdownRenderer.render(source, config: config)
        let nsString = rendered.string as NSString
        let firstParagraphEnd = NSMaxRange(nsString.range(of: "x*b"))
        let secondB = nsString.range(
            of: "b",
            options: [],
            range: NSRange(location: firstParagraphEnd, length: nsString.length - firstParagraphEnd)
        )
        let tail = nsString.range(of: "ZZZ")
        XCTAssertNotEqual(secondB.location, NSNotFound)
        XCTAssertNotEqual(tail.location, NSNotFound)

        let markdown = MarkdownExtractor.markdown(
            for: NSUnionRange(secondB, tail),
            in: rendered,
            sourceMarkdown: source
        )

        XCTAssertEqual(markdown, "b\n\nZZZ")
    }

    // MARK: - Attachments

    func testTableSelectionSlicesOriginalDelimiters() {
        let source = "before\n\n| A |\n|:----|\n| x |\n\nafter"
        let rendered = MarkdownRenderer.render(source, config: config)
        let nsString = rendered.string as NSString
        let beforeRange = nsString.range(of: "before")
        let tableRange = nsString.range(of: "\u{FFFC}")
        XCTAssertNotEqual(beforeRange.location, NSNotFound)
        XCTAssertNotEqual(tableRange.location, NSNotFound)

        let markdown = MarkdownExtractor.markdown(
            for: NSUnionRange(beforeRange, tableRange),
            in: rendered,
            sourceMarkdown: source
        )

        XCTAssertEqual(markdown, "before\n\n| A |\n|:----|\n| x |")
    }

    func testThematicBreakSelectionSlicesVerbatim() {
        let source = "zero\n\none\n\n---\n\ntwo\n\nmore"
        let rendered = MarkdownRenderer.render(source, config: config)
        let nsString = rendered.string as NSString
        let selection = NSUnionRange(nsString.range(of: "one"), nsString.range(of: "two"))

        let markdown = MarkdownExtractor.markdown(for: selection, in: rendered, sourceMarkdown: source)

        XCTAssertEqual(markdown, "one\n\n---\n\ntwo")
    }

    func testImageSelectionSlicesVerbatim() {
        let source = "intro ![p](https://a.com/i.png) outro\n\ntail"
        let rendered = MarkdownRenderer.render(source, config: config)
        let nsString = rendered.string as NSString
        let selection = NSUnionRange(nsString.range(of: "intro"), nsString.range(of: "outro"))

        let markdown = MarkdownExtractor.markdown(for: selection, in: rendered, sourceMarkdown: source)

        XCTAssertEqual(markdown, "intro ![p](https://a.com/i.png) outro")
    }

    func testImageOnlySelectionSlicesFullSyntax() {
        let source = "intro ![p](https://a.com/i.png) outro\n\ntail"
        let rendered = MarkdownRenderer.render(source, config: config)
        let selection = (rendered.string as NSString).range(of: "\u{FFFC}")
        XCTAssertNotEqual(selection.location, NSNotFound)

        let markdown = MarkdownExtractor.markdown(for: selection, in: rendered, sourceMarkdown: source)

        XCTAssertEqual(markdown, "![p](https://a.com/i.png)")
    }

    func testSetextHeadingSelectionIncludesUnderline() {
        XCTAssertEqual(
            copyMarkdown(selecting: "Title Here", in: "intro\n\nTitle Here\n------\n\nafter"),
            "Title Here\n------"
        )
    }

    /// A setext underline looks like a thematic break to the structural
    /// scan, so the break after one anchors to the wrong line; the
    /// structural counts in validation must reject the duplicated `---`.
    func testMisAnchoredThematicBreakFallsBackToReconstruction() {
        let source = "T\n---\n\n---\n\nend"
        let rendered = MarkdownRenderer.render(source, config: config)
        let nsString = rendered.string as NSString
        let breakRange = nsString.range(of: "\u{FFFC}")
        let tail = nsString.range(of: "end")
        XCTAssertNotEqual(breakRange.location, NSNotFound)
        XCTAssertNotEqual(tail.location, NSNotFound)

        let markdown = MarkdownExtractor.markdown(
            for: NSUnionRange(breakRange, tail),
            in: rendered,
            sourceMarkdown: source
        )

        XCTAssertEqual(markdown, "---\n\nend")
    }
}
