import UIKit
import XCTest
@testable import EnrichedMarkdown

final class HTMLGeneratorTests: XCTestCase {
    private var config: MarkdownStyleConfig!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.resolve(layers: [.default], traitCollection: .current)
    }

    private func html(for markdown: String, flags: Md4cFlags = .commonMark) -> String {
        let rendered = MarkdownRenderer.render(markdown, config: config, flags: flags)
        return MarkdownHTMLGenerator.generateHTML(
            from: rendered,
            in: NSRange(location: 0, length: rendered.length),
            config: config
        )
    }

    func testEmptyRangeYieldsEmptyDocument() {
        XCTAssertEqual(
            MarkdownHTMLGenerator.generateHTML(
                from: NSAttributedString(),
                in: NSRange(location: 0, length: 0),
                config: config
            ),
            "<html></html>"
        )
    }

    func testDocumentIsWrappedInHTMLTags() {
        let result = html(for: "Hello")

        XCTAssertTrue(result.hasPrefix("<html>"))
        XCTAssertTrue(result.hasSuffix("</html>"))
    }

    func testParagraphCarriesConfiguredStyles() {
        let result = html(for: "Hello world")

        XCTAssertTrue(result.contains("<p style=\""))
        XCTAssertTrue(result.contains("Hello world</p>"))
        XCTAssertTrue(result.contains("font-size:"))
        XCTAssertTrue(result.contains("color:"))
    }

    func testHeadingsUseSemanticTagsWithFontSize() {
        let result = html(for: "# First\n\n### Third")

        XCTAssertTrue(result.contains("<h1 style=\"font-size:"))
        XCTAssertTrue(result.contains("First</h1>"))
        XCTAssertTrue(result.contains("<h3 style=\"font-size:"))
        XCTAssertTrue(result.contains("Third</h3>"))
    }

    func testBoldAndItalic() {
        let result = html(for: "**bold** and *italic*")

        XCTAssertTrue(result.contains("<strong>bold</strong>"))
        XCTAssertTrue(result.contains("<em>italic</em>"))
    }

    func testStrikethroughEmitsS() {
        let result = html(for: "~~gone~~")

        XCTAssertTrue(result.contains("<s>gone</s>"))
    }

    func testUnderlineEmitsU() {
        let result = html(for: "__under__", flags: Md4cFlags(underline: true))

        XCTAssertTrue(result.contains("<u>under</u>"))
    }

    func testLinkCarriesHrefAndStyle() {
        let result = html(for: "[press](https://swmansion.com)")

        XCTAssertTrue(result.contains("<a href=\"https://swmansion.com\" style=\"color:"))
        XCTAssertTrue(result.contains("press</a>"))
        XCTAssertTrue(result.contains("text-decoration: underline"))
    }

    func testLinkTextIsNotDoubleUnderlined() {
        let result = html(for: "[press](https://swmansion.com)")

        XCTAssertFalse(result.contains("<u><a"))
        XCTAssertFalse(result.contains("<a href=\"https://swmansion.com\" style=\"color: inherit\"><u>"))
    }

    func testInlineCodeUsesCodeTag() {
        let result = html(for: "run `swift test` now")

        XCTAssertTrue(result.contains("<code style=\"background-color:"))
        XCTAssertTrue(result.contains("swift test</code>"))
    }

    func testCodeBlockUsesPreAndCode() {
        let result = html(for: "```\nlet x = 1\nlet y = 2\n```")

        XCTAssertTrue(result.contains("<pre dir=\"ltr\" style=\"background-color:"))
        XCTAssertTrue(result.contains("<code style=\"font-family: Menlo"))
        XCTAssertTrue(result.contains("let x = 1\nlet y = 2</code></pre>"))
    }

    func testCodeBlockPaddingSpacersAreTrimmed() {
        let result = html(for: "```\ncontent\n```")

        XCTAssertTrue(result.contains("<code style=\"font-family: Menlo, Monaco, Consolas, monospace; font-size:"))
        XCTAssertFalse(result.contains(">\ncontent"))
        XCTAssertTrue(result.contains("content</code></pre>"))
    }

    func testCodeBlockContentIsEscapedNotStyled() {
        let result = html(for: "```\na < b && c > d\n```")

        XCTAssertTrue(result.contains("a &lt; b &amp;&amp; c &gt; d"))
    }

    func testBlockquoteEmitsBorderAndInnerParagraph() {
        let result = html(for: "> quoted text")

        XCTAssertTrue(result.contains("<blockquote style=\"background-color:"))
        XCTAssertTrue(result.contains("border-inline-start:"))
        XCTAssertTrue(result.contains("quoted text</p>"))
        XCTAssertTrue(result.contains("</blockquote>"))
    }

    func testNestedBlockquotes() {
        let result = html(for: "> outer\n>> inner")

        XCTAssertEqual(result.components(separatedBy: "<blockquote").count - 1, 2)
        XCTAssertEqual(result.components(separatedBy: "</blockquote>").count - 1, 2)
        XCTAssertTrue(result.contains("padding-inline-start:"))
    }

    func testUnorderedList() {
        let result = html(for: "- one\n- two")

        XCTAssertTrue(result.contains("<ul style=\""))
        XCTAssertTrue(result.contains("list-style-type: disc"))
        XCTAssertTrue(result.contains("<li style=\""))
        XCTAssertTrue(result.contains("one</li>"))
        XCTAssertTrue(result.contains("two</li>"))
        XCTAssertTrue(result.contains("</ul>"))
    }

    func testOrderedList() {
        let result = html(for: "1. first\n2. second")

        XCTAssertTrue(result.contains("<ol style=\""))
        XCTAssertTrue(result.contains("first</li>"))
        XCTAssertTrue(result.contains("second</li>"))
        XCTAssertTrue(result.contains("</ol>"))
    }

    func testTaskListItemsEmitDisabledCheckboxes() {
        let result = html(for: "- [x] done\n- [ ] todo")

        XCTAssertTrue(result.contains("<input type=\"checkbox\" disabled checked "))
        XCTAssertTrue(result.contains("<input type=\"checkbox\" disabled style"))
        XCTAssertTrue(result.contains("list-style-type: none;"))
        XCTAssertTrue(result.contains("done</li>"))
        XCTAssertTrue(result.contains("todo</li>"))
    }

    func testRegularListItemsEmitNoCheckbox() {
        let result = html(for: "- plain")

        XCTAssertFalse(result.contains("checkbox"))
        XCTAssertFalse(result.contains("list-style-type: none"))
    }

    func testNestedListsOpenSecondContainer() {
        let result = html(for: "- outer\n  - inner")

        XCTAssertEqual(result.components(separatedBy: "<ul").count - 1, 2)
        XCTAssertEqual(result.components(separatedBy: "</ul>").count - 1, 2)
    }

    func testListTypeChangeAtSameDepthClosesContainer() {
        let result = html(for: "- bullet\n\n1. number")

        XCTAssertTrue(result.contains("</ul>"))
        XCTAssertTrue(result.contains("<ol"))
        XCTAssertLessThan(
            result.range(of: "</ul>")!.lowerBound,
            result.range(of: "<ol")!.lowerBound
        )
    }

    func testBlockImageEmitsImgWithMaxWidth() {
        let result = html(for: "![alt](https://example.invalid/pic.png)")

        XCTAssertTrue(result.contains("<img src=\"https://example.invalid/pic.png\""))
        XCTAssertTrue(result.contains("max-width: 100%"))
    }

    func testInlineImageUsesEmHeight() {
        let result = html(for: "text ![icon](https://example.invalid/icon.png) more")

        XCTAssertTrue(result.contains("<img src=\"https://example.invalid/icon.png\" style=\"height: 1.2em;"))
    }

    func testTextIsHTMLEscaped() {
        let result = html(for: "a \\<script\\> & \"quote\"")

        XCTAssertTrue(result.contains("&lt;script&gt;"))
        XCTAssertTrue(result.contains("&amp;"))
        XCTAssertTrue(result.contains("&quot;quote&quot;"))
        XCTAssertFalse(result.contains("<script>"))
    }

    func testHardLineBreakEmitsBr() {
        let result = html(for: "line one  \nline two")

        XCTAssertTrue(result.contains("<br>"))
    }

    func testRTLWrapsDocumentInDirectionalDiv() {
        let rendered = MarkdownRenderer.render("مرحبا", config: config)
        let result = MarkdownHTMLGenerator.generateHTML(
            from: rendered,
            in: NSRange(location: 0, length: rendered.length),
            config: config,
            isRTL: true
        )

        XCTAssertTrue(result.hasPrefix("<html dir=\"rtl\">"))
        XCTAssertTrue(result.contains("direction: rtl"))
        XCTAssertTrue(result.hasSuffix("</div></html>"))
    }

    func testPartialRangeGeneratesOnlySelection() {
        let rendered = MarkdownRenderer.render("Hello world", config: config)
        let range = (rendered.string as NSString).range(of: "world")

        let result = MarkdownHTMLGenerator.generateHTML(from: rendered, in: range, config: config)

        XCTAssertTrue(result.contains("world"))
        XCTAssertFalse(result.contains("Hello"))
    }
}

final class MarkdownTextViewCopyTests: XCTestCase {
    private var config: MarkdownStyleConfig!
    private var pasteboard: UIPasteboard!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.resolve(layers: [.default], traitCollection: .current)
        // UIPasteboard.general is not accessible from a headless test process.
        pasteboard = UIPasteboard.withUniqueName()
    }

    override func tearDown() {
        UIPasteboard.remove(withName: pasteboard.name)
        super.tearDown()
    }

    private func makeTextView(markdown: String) -> MarkdownTextView {
        let textView = MarkdownTextView()
        textView.pasteboard = pasteboard
        textView.setMarkdownAttributedText(MarkdownRenderer.render(markdown, config: config))
        return textView
    }

    func testCopyPutsPlainAndHTMLFlavorsOnPasteboard() {
        let textView = makeTextView(markdown: "**bold** text")
        textView.selectedRange = NSRange(location: 0, length: textView.attributedText.length)

        textView.copy(nil)

        let item = pasteboard.items.first
        XCTAssertNotNil(item)
        XCTAssertTrue((item?["public.utf8-plain-text"] as? String)?.contains("bold text") == true)
        XCTAssertTrue((item?["public.html"] as? String)?.contains("<strong>bold</strong>") == true)
    }

    func testCopyWithEmptySelectionWritesNoFlavors() {
        let textView = makeTextView(markdown: "plain")
        textView.selectedRange = NSRange(location: 0, length: 0)

        textView.copy(nil)

        XCTAssertNil(pasteboard.items.first?["public.html"])
    }
}
