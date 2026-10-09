import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class TrailingSpacingTests: XCTestCase {
    private var config: MarkdownStyleConfiguration!
    private var window: UIWindow?

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfiguration.baseline()
    }

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func render(
        _ markdown: String,
        options: MarkdownParsingOptions = .commonMark,
        config: MarkdownStyleConfiguration? = nil
    ) -> NSAttributedString {
        MarkdownRenderer.render(markdown, config: config ?? self.config, options: options)
    }

    private func paragraphSpacing(in text: NSAttributedString, at location: Int) -> CGFloat? {
        (text.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle)?.paragraphSpacing
    }

    private func withoutSpacing(_ text: NSAttributedString) -> NSAttributedString {
        let bare = NSMutableAttributedString(attributedString: text)
        bare.removeAttribute(MarkdownAttribute.trailingSpacing, range: NSRange(location: 0, length: bare.length))
        return bare
    }

    private func hostedTextView(_ text: NSAttributedString, marginEnabled: Bool) throws -> MarkdownTextView {
        let (window, textView) = try host(.fixture(attributedText: text, isBottomMarginEnabled: marginEnabled))
        self.window = window
        return textView
    }

    // MARK: - Stripping

    func testParagraphEndsAtItsTextWithTheMarginRecorded() {
        let text = render("Para")

        XCTAssertEqual(text.string, "Para")
        XCTAssertEqual(paragraphSpacing(in: text, at: 3), 0)
        XCTAssertEqual(TrailingSpacing.read(from: text), TrailingSpacing(margin: 16))
    }

    func testInteriorBlocksKeepTheirMargins() {
        let text = render("First\n\nSecond")

        XCTAssertEqual(text.string, "First\nSecond")
        XCTAssertEqual(paragraphSpacing(in: text, at: 0), 16)
        XCTAssertEqual(paragraphSpacing(in: text, at: 6), 0)
    }

    private struct TrailingBlock {
        let markdown: String
        let suffix: String
        let margin: CGFloat?
    }

    func testEveryBlockEndsAtItsContentWithItsMarginRecorded() {
        let blocks = [
            TrailingBlock(markdown: "# Title", suffix: "Title", margin: config.heading1.marginBottom),
            TrailingBlock(markdown: "- one\n- two", suffix: "two", margin: config.list.marginBottom),
            TrailingBlock(markdown: "> quote", suffix: "quote", margin: config.blockquote.marginBottom),
            TrailingBlock(markdown: "| a | b |\n|---|---|\n| 1 | 2 |", suffix: "\u{FFFC}", margin: config.table.marginBottom),
            TrailingBlock(
                markdown: "![alt](https://example.invalid/image.png)",
                suffix: "\u{FFFC}",
                margin: config.image.marginBottom
            )
        ]
        for block in blocks {
            let text = render(block.markdown)
            XCTAssertTrue(text.string.hasSuffix(block.suffix), block.markdown)
            XCTAssertEqual(TrailingSpacing.read(from: text), TrailingSpacing(margin: block.margin ?? 0), block.markdown)
        }
    }

    func testThematicBreakMarginMovesOutOfTheAttachment() throws {
        let text = render("Para\n\n---")
        let rule = try XCTUnwrap(text.attribute(.attachment, at: text.length - 1, effectiveRange: nil) as? ThematicBreakAttachment)

        XCTAssertEqual(TrailingSpacing.read(from: text), TrailingSpacing(margin: 24))
        XCTAssertEqual(rule.marginBottom, 0)
        XCTAssertEqual(rule.marginTop, 24)
    }

    func testCodeBlockKeepsItsPaddingAsSpacing() {
        let text = render("```\ncode\n```")

        XCTAssertTrue(text.string.hasSuffix("code"))
        XCTAssertEqual(TrailingSpacing.read(from: text), TrailingSpacing(margin: 16, padding: 12))
        XCTAssertEqual(MarkdownAttributeValue.codeBlockRange(in: text, at: text.length - 1)?.upperBound, text.length)
    }

    func testCodeBlockEndingAListRecordsTheLargerMargin() {
        var listConfig = config!
        listConfig.list.marginBottom = 40
        let text = render("- item\n\n  ```\n  code\n  ```", config: listConfig)

        XCTAssertTrue(text.string.hasSuffix("code"))
        XCTAssertEqual(TrailingSpacing.read(from: text), TrailingSpacing(margin: 40, padding: 12))
    }

    func testTrailingBlankLinesAreStripped() {
        let text = render("Para\n\n\n\n", options: MarkdownParsingOptions(preserveBlankLines: true))

        XCTAssertEqual(text.string, "Para")
    }

    func testTheSpacingRidesAlongWithTheText() throws {
        let revealed = try XCTUnwrap(SpoilerInteraction.revealing(in: render("||hidden||"), ordinals: [0]))
        XCTAssertEqual(TrailingSpacing.read(from: revealed), TrailingSpacing(margin: 16))

        let toggled = try XCTUnwrap(
            TaskListInteraction.togglingItem(in: render("- [ ] task"), index: 0, checked: true, config: config)
        )
        XCTAssertEqual(TrailingSpacing.read(from: toggled), TrailingSpacing(margin: config.list.marginBottom ?? 0))
    }

    // MARK: - Layout

    func testEnvironmentDefault() {
        XCTAssertFalse(EnvironmentValues().markdownBottomMarginEnabled)
    }

    func testTheMarginIsAddedToTheHeightOnlyWhenEnabled() {
        let text = render("Para")
        let textView = MarkdownTextView()
        textView.setMarkdownAttributedText(withoutSpacing(text))
        let bare = height(of: textView)

        textView.setMarkdownAttributedText(text)
        XCTAssertEqual(height(of: textView), bare, accuracy: 0.001)

        textView.isBottomMarginEnabled = true
        XCTAssertEqual(height(of: textView), bare + 16, accuracy: 0.001)

        textView.isBottomMarginEnabled = false
        XCTAssertEqual(height(of: textView), bare, accuracy: 0.001)
    }

    func testACodeBlockKeepsItsPaddingBelowTheText() {
        let text = render("```\ncode\n```")
        let textView = MarkdownTextView()
        textView.setMarkdownAttributedText(withoutSpacing(text))
        let bare = height(of: textView)

        textView.setMarkdownAttributedText(text)
        XCTAssertEqual(height(of: textView), bare + 12, accuracy: 0.001)

        textView.isBottomMarginEnabled = true
        XCTAssertEqual(height(of: textView), bare + 12 + 16, accuracy: 0.001)
    }

    func testEnablingTheMarginKeepsTheLayout() throws {
        let textView = laidOutTextView(showing: render("Para"))
        let textLayoutManager = try XCTUnwrap(textView.textLayoutManager)

        textView.isBottomMarginEnabled = true
        _ = height(of: textView, width: 390)

        let fragment = textLayoutManager.textLayoutFragment(for: textLayoutManager.documentRange.location)
        XCTAssertEqual(fragment?.state, .layoutAvailable)
        XCTAssertEqual(textView.textContainerInset, .zero)
    }

    func testHostedViewAddsTheMarginBelowTheText() throws {
        let text = render("Para")
        let bare = try hostedTextView(text, marginEnabled: false).frame.height

        let withMargin = try hostedTextView(text, marginEnabled: true)

        XCTAssertEqual(withMargin.frame.height, bare + 16, accuracy: 0.001)
    }

    func testTrailingCodeBlockBackgroundCoversItsPadding() throws {
        let textView = try hostedTextView(render("```\ncode\n```"), marginEnabled: false)
        let bottom = textView.bounds.height

        let inPadding = try backgroundPixel(of: textView, at: CGPoint(x: 100, y: bottom - 4))

        XCTAssertNotEqual(inPadding, [255, 255, 255, 255])
        XCTAssertEqual(inPadding, try backgroundPixel(of: textView, at: CGPoint(x: 100, y: 6)))
    }

    func testTrailingCodeBlockBackgroundStopsAtTheMargin() throws {
        let textView = try hostedTextView(render("```\ncode\n```"), marginEnabled: true)
        let bottom = textView.bounds.height

        XCTAssertEqual(try backgroundPixel(of: textView, at: CGPoint(x: 100, y: bottom - 4)), [255, 255, 255, 255])
        XCTAssertNotEqual(try backgroundPixel(of: textView, at: CGPoint(x: 100, y: bottom - 16 - 4)), [255, 255, 255, 255])
    }
}
