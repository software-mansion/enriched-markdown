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
            source: RenderedSource(markdown: "Forests cover **31%** of land.", flags: .commonMark)
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
            source: RenderedSource(markdown: source, flags: .commonMark)
        )

        XCTAssertEqual(specs.first?.pasteboardString, source)
    }

    func testBuildOmitsCopyMarkdownWhenDisabled() {
        let rendered = render("Hello world")

        let specs = SelectionMenuItems.build(
            config: MarkdownSelectionMenuConfig(copyAsMarkdown: false),
            selectedRange: fullRange(of: rendered),
            attributedText: rendered,
            source: RenderedSource(markdown: "Hello world", flags: .commonMark)
        )

        XCTAssertTrue(specs.isEmpty)
    }

    func testBuildUsesCustomLabel() {
        let rendered = render("Hello world")

        let specs = SelectionMenuItems.build(
            config: MarkdownSelectionMenuConfig(copyAsMarkdownLabel: "Kopiuj jako Markdown"),
            selectedRange: fullRange(of: rendered),
            attributedText: rendered,
            source: RenderedSource(markdown: "Hello world", flags: .commonMark)
        )

        XCTAssertEqual(specs.first?.title, "Kopiuj jako Markdown")
    }

    func testBuildReturnsEmptyForZeroLengthSelection() {
        let rendered = render("Hello world")

        let specs = SelectionMenuItems.build(
            config: MarkdownSelectionMenuConfig(),
            selectedRange: NSRange(location: 0, length: 0),
            attributedText: rendered,
            source: RenderedSource(markdown: "Hello world", flags: .commonMark)
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
            source: RenderedSource(markdown: "No images here.", flags: .commonMark)
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
            source: RenderedSource(markdown: source, flags: .commonMark)
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
            source: RenderedSource(markdown: source, flags: .commonMark)
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
            source: RenderedSource(markdown: source, flags: .commonMark)
        )

        XCTAssertFalse(specs.contains { $0.kind == .copyImageURLs })
    }

    func testImageURLsTitlePluralization() {
        XCTAssertEqual(SelectionMenuItems.imageURLsTitle(count: 1), "Copy Image URL")
        XCTAssertEqual(SelectionMenuItems.imageURLsTitle(count: 3), "Copy 3 Image URLs")
    }

    // MARK: - Menu splicing

    func testSpliceInsertsAfterStandardEditMenu() {
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

    // MARK: - Select All fallback

    func testContainsSelectAllDetectsCommandNestedInStandardEditMenu() {
        let selectAll = UICommand(title: "Select All", action: #selector(UIResponder.selectAll(_:)))
        let copy = UICommand(title: "Copy", action: #selector(UIResponder.copy(_:)))
        let standardEdit = UIMenu(title: "", identifier: .standardEdit, children: [copy, selectAll])

        XCTAssertTrue(MarkdownTextViewRepresentable.Coordinator.containsSelectAll([standardEdit]))
        XCTAssertFalse(MarkdownTextViewRepresentable.Coordinator.containsSelectAll([
            UIMenu(title: "", identifier: .standardEdit, children: [copy])
        ]))
    }

    func testMakeSelectAllActionAttributes() {
        let action = MarkdownTextViewRepresentable.Coordinator.makeSelectAllAction(for: UITextView())

        XCTAssertEqual(action.title, "Select All")
        XCTAssertEqual(action.identifier.rawValue, "com.swmansion.enriched.markdown.selectAll")
    }

    func testSelectEntireDocumentSelectsFullRange() {
        let textView = UITextView()
        textView.attributedText = render("Hello **world** out there")
        textView.selectedRange = NSRange(location: 0, length: 5)

        MarkdownTextViewRepresentable.Coordinator.selectEntireDocument(in: textView)

        XCTAssertEqual(textView.selectedRange, NSRange(location: 0, length: textView.attributedText.length))
    }

    func testSplicePrependsWhenStandardEditMenuAbsent() {
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
