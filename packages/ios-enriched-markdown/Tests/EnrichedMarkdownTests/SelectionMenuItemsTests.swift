import UIKit
import XCTest
@testable import EnrichedMarkdown

final class SelectionMenuItemsTests: XCTestCase {
    private var config: MarkdownStyleConfig!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.baseline()
    }

    private func render(_ markdown: String) -> NSAttributedString {
        MarkdownRenderer.render(markdown, config: config)
    }

    private func fullRange(of attributedText: NSAttributedString) -> NSRange {
        NSRange(location: 0, length: attributedText.length)
    }

    // MARK: - Copy as Markdown

    func testBuildIncludesCopyMarkdownForPartialSelection() {
        let rendered = render("Forests cover **31%** of land.")
        let range = (rendered.string as NSString).range(of: "31%")

        let specs = SelectionMenuItems.build(
            config: MarkdownSelectionMenuConfig(),
            selectedRange: range,
            attributedText: rendered,
            sourceMarkdown: "Forests cover **31%** of land."
        )

        XCTAssertEqual(specs.count, 1)
        XCTAssertEqual(specs.first?.kind, .copyMarkdown)
        XCTAssertEqual(specs.first?.title, "Copy as Markdown")
        XCTAssertEqual(specs.first?.systemImageName, "doc.text")
        XCTAssertEqual(specs.first?.identifier, SelectionMenuItems.copyMarkdownIdentifier)
        XCTAssertEqual(specs.first?.pasteboardString, "**31%**")
    }

    func testBuildReturnsSourceMarkdownVerbatimForFullSelection() {
        let source = "# Title\n\nParagraph with **bold**."
        let rendered = render(source)

        let specs = SelectionMenuItems.build(
            config: MarkdownSelectionMenuConfig(),
            selectedRange: fullRange(of: rendered),
            attributedText: rendered,
            sourceMarkdown: source
        )

        XCTAssertEqual(specs.first?.pasteboardString, source)
    }

    func testBuildOmitsCopyMarkdownWhenDisabled() {
        let rendered = render("Hello world")

        let specs = SelectionMenuItems.build(
            config: MarkdownSelectionMenuConfig(copyAsMarkdown: false),
            selectedRange: fullRange(of: rendered),
            attributedText: rendered,
            sourceMarkdown: "Hello world"
        )

        XCTAssertTrue(specs.isEmpty)
    }

    func testBuildUsesCustomLabel() {
        let rendered = render("Hello world")

        let specs = SelectionMenuItems.build(
            config: MarkdownSelectionMenuConfig(copyAsMarkdownLabel: "Kopiuj jako Markdown"),
            selectedRange: fullRange(of: rendered),
            attributedText: rendered,
            sourceMarkdown: "Hello world"
        )

        XCTAssertEqual(specs.first?.title, "Kopiuj jako Markdown")
    }

    func testBuildReturnsEmptyForZeroLengthSelection() {
        let rendered = render("Hello world")

        let specs = SelectionMenuItems.build(
            config: MarkdownSelectionMenuConfig(),
            selectedRange: NSRange(location: 0, length: 0),
            attributedText: rendered,
            sourceMarkdown: "Hello world"
        )

        XCTAssertTrue(specs.isEmpty)
    }

    // MARK: - Copy Image URL

    func testBuildOmitsImageActionWhenNoImages() {
        let rendered = render("No images here.")

        let specs = SelectionMenuItems.build(
            config: MarkdownSelectionMenuConfig(),
            selectedRange: fullRange(of: rendered),
            attributedText: rendered,
            sourceMarkdown: "No images here."
        )

        XCTAssertEqual(specs.map(\.kind), [.copyMarkdown])
    }

    func testBuildIncludesImageActionWithHttpUrls() {
        let source = "![image](https://example.com/forest.jpg)"
        let rendered = render(source)

        let specs = SelectionMenuItems.build(
            config: MarkdownSelectionMenuConfig(),
            selectedRange: fullRange(of: rendered),
            attributedText: rendered,
            sourceMarkdown: source
        )

        let imageSpec = specs.first { $0.kind == .copyImageURLs }
        XCTAssertEqual(imageSpec?.title, "Copy Image URL")
        XCTAssertEqual(imageSpec?.systemImageName, "link")
        XCTAssertEqual(imageSpec?.identifier, SelectionMenuItems.copyImageURLIdentifier)
        XCTAssertEqual(imageSpec?.pasteboardString, "https://example.com/forest.jpg")
    }

    func testBuildJoinsMultipleImageURLsWithNewline() {
        let source = "![image](https://example.com/a.jpg)\n\n![image](https://example.com/b.jpg)"
        let rendered = render(source)

        let specs = SelectionMenuItems.build(
            config: MarkdownSelectionMenuConfig(),
            selectedRange: fullRange(of: rendered),
            attributedText: rendered,
            sourceMarkdown: source
        )

        let imageSpec = specs.first { $0.kind == .copyImageURLs }
        XCTAssertEqual(imageSpec?.title, "Copy 2 Image URLs")
        XCTAssertEqual(imageSpec?.pasteboardString, "https://example.com/a.jpg\nhttps://example.com/b.jpg")
    }

    func testBuildOmitsImageActionWhenDisabled() {
        let source = "![image](https://example.com/forest.jpg)"
        let rendered = render(source)

        let specs = SelectionMenuItems.build(
            config: MarkdownSelectionMenuConfig(copyImageUrl: false),
            selectedRange: fullRange(of: rendered),
            attributedText: rendered,
            sourceMarkdown: source
        )

        XCTAssertFalse(specs.contains { $0.kind == .copyImageURLs })
    }

    func testImageURLsTitlePluralization() {
        XCTAssertEqual(SelectionMenuItems.imageURLsTitle(count: 1), "Copy Image URL")
        XCTAssertEqual(SelectionMenuItems.imageURLsTitle(count: 3), "Copy 3 Image URLs")
    }

    // MARK: - Menu splicing

    func testSpliceInsertsAfterStandardEditMenu() throws {
        guard #available(iOS 16.0, *) else { throw XCTSkip("Requires iOS 16") }

        let standardEdit = UIMenu(title: "", identifier: .standardEdit, children: [])
        let lookUp = UIMenu(title: "", identifier: .lookup, children: [])
        let custom = UIAction(title: "Copy as Markdown") { _ in }

        let result = MarkdownTextViewRepresentable.Coordinator.splice(
            [custom],
            into: [standardEdit, lookUp]
        )

        XCTAssertEqual(result.count, 3)
        XCTAssertTrue((result[0] as? UIMenu)?.identifier == .standardEdit)
        XCTAssertTrue(result[1] === custom)
        XCTAssertTrue((result[2] as? UIMenu)?.identifier == .lookup)
    }

    func testSplicePrependsWhenStandardEditMenuAbsent() throws {
        guard #available(iOS 16.0, *) else { throw XCTSkip("Requires iOS 16") }

        let lookUp = UIMenu(title: "", identifier: .lookup, children: [])
        let custom = UIAction(title: "Copy as Markdown") { _ in }

        let result = MarkdownTextViewRepresentable.Coordinator.splice(
            [custom],
            into: [lookUp]
        )

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result[0] === custom)
        XCTAssertTrue((result[1] as? UIMenu)?.identifier == .lookup)
    }
}
