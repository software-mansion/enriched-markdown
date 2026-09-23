import Combine
import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class WritingDirectionTests: XCTestCase {
    private var config: MarkdownStyleConfig!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.baseline()
    }

    // MARK: - First-strong detection

    func testFirstStrongDetectsRightToLeftScripts() {
        XCTAssertEqual(WritingDirectionResolver.firstStrongDirection(of: "مرحبا بالعالم"), .rightToLeft)
        XCTAssertEqual(WritingDirectionResolver.firstStrongDirection(of: "שלום עולם"), .rightToLeft)
        XCTAssertEqual(WritingDirectionResolver.firstStrongDirection(of: "سلام دنیا"), .rightToLeft)
    }

    func testFirstStrongDetectsLeftToRightScripts() {
        XCTAssertEqual(WritingDirectionResolver.firstStrongDirection(of: "Hello"), .leftToRight)
        XCTAssertEqual(WritingDirectionResolver.firstStrongDirection(of: "こんにちは"), .leftToRight)
    }

    func testFirstStrongSkipsLeadingNeutralCharacters() {
        XCTAssertEqual(WritingDirectionResolver.firstStrongDirection(of: "123 مرحبا"), .rightToLeft)
        XCTAssertEqual(WritingDirectionResolver.firstStrongDirection(of: "(\"Hello\") مرحبا"), .leftToRight)
    }

    func testFirstStrongIsNaturalWithoutLetters() {
        XCTAssertEqual(WritingDirectionResolver.firstStrongDirection(of: "123 456."), .natural)
        XCTAssertEqual(WritingDirectionResolver.firstStrongDirection(of: ""), .natural)
    }

    // MARK: - Rendered paragraphs

    func testParagraphsResolveFromTheirOwnContent() {
        // Emoji: non-letters, two UTF-16 units each.
        let rendered = render("😀 Hello\n\n🙂🙂 مرحبا\n\nשלום")

        XCTAssertEqual(direction(of: "Hello", in: rendered), .leftToRight)
        XCTAssertEqual(direction(of: "مرحبا", in: rendered), .rightToLeft)
        XCTAssertEqual(direction(of: "שלום", in: rendered), .rightToLeft)
    }

    func testNeutralParagraphFollowsLayoutDirection() {
        XCTAssertEqual(direction(of: "123", in: render("مرحبا\n\n123")), .leftToRight)

        let rightToLeftLayout = render("Hello\n\n123", layoutDirection: .rightToLeft)
        XCTAssertEqual(direction(of: "123", in: rightToLeftLayout), .rightToLeft)
        XCTAssertEqual(direction(of: "Hello", in: rightToLeftLayout), .leftToRight)
    }

    func testForcedDirectionsOverrideContent() {
        XCTAssertEqual(direction(of: "Hello", in: render("Hello", writingDirection: .rightToLeft)), .rightToLeft)
        XCTAssertEqual(direction(of: "مرحبا", in: render("مرحبا", writingDirection: .leftToRight)), .leftToRight)
    }

    func testNaturalLeavesParagraphsToTextKit() {
        XCTAssertEqual(direction(of: "مرحبا", in: render("مرحبا", writingDirection: .natural)), .natural)
    }

    func testCodeBlocksStayLeftToRight() {
        let markdown = "```\nمرحبا\n```"

        XCTAssertEqual(direction(of: "مرحبا", in: render(markdown)), .leftToRight)
        XCTAssertEqual(direction(of: "مرحبا", in: render(markdown, writingDirection: .rightToLeft)), .leftToRight)
    }

    func testHeadingsListsAndQuotesFollowTheirParagraph() {
        let rendered = render("# عنوان\n\n- مرحبا\n- Hello\n\n> שלום\n>\n> World")

        XCTAssertEqual(direction(of: "عنوان", in: rendered), .rightToLeft)
        XCTAssertEqual(direction(of: "مرحبا", in: rendered), .rightToLeft)
        XCTAssertEqual(direction(of: "Hello", in: rendered), .leftToRight)
        XCTAssertEqual(direction(of: "שלום", in: rendered), .rightToLeft)
        XCTAssertEqual(direction(of: "World", in: rendered), .leftToRight)
    }

    /// Nested titles are skipped; text after the quote is not consulted.
    func testAdmonitionTitleFollowsItsBody() {
        XCTAssertEqual(titleDirection("> [!NOTE]\n> مرحبا"), .rightToLeft)
        XCTAssertEqual(titleDirection("> [!NOTE]\n> Hello"), .leftToRight)
        XCTAssertEqual(titleDirection("> [!NOTE]\n> 123\n>\n> مرحبا"), .rightToLeft)
        XCTAssertEqual(titleDirection("> [!NOTE]\n> > [!TIP]\n> > مرحبا"), .rightToLeft)
        XCTAssertEqual(titleDirection("> [!NOTE]\n\nمرحبا"), .leftToRight)
    }

    func testBodilessAdmonitionTitleFollowsLayoutDirection() {
        XCTAssertEqual(titleDirection("> [!NOTE]"), .leftToRight)
        XCTAssertEqual(titleDirection("> [!NOTE]", layoutDirection: .rightToLeft), .rightToLeft)
    }

    func testTableCellsResolveIndependently() throws {
        let rendered = render("| a | b |\n|---|---|\n| Hello | مرحبا |")
        let table = try XCTUnwrap(tableAttachment(in: rendered))

        XCTAssertEqual(direction(of: "Hello", in: table.model.rows[1][0].attributedText), .leftToRight)
        XCTAssertEqual(direction(of: "مرحبا", in: table.model.rows[1][1].attributedText), .rightToLeft)
    }

    func testEnvironmentDefaultsToFirstStrong() {
        XCTAssertEqual(EnvironmentValues().markdownWritingDirection, .firstStrong)
    }

    @MainActor
    func testStoreRendersWithTheRequestedDirection() {
        let store = MarkdownRenderStore()

        renderSynchronously(store, markdown: "123", layoutDirection: .rightToLeft)

        XCTAssertEqual(direction(of: "123", in: store.attributedText), .rightToLeft)
    }

    // MARK: - Helpers

    private func render(
        _ markdown: String,
        writingDirection: MarkdownWritingDirection = .firstStrong,
        layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight
    ) -> NSAttributedString {
        MarkdownRenderer.render(
            markdown,
            config: config,
            flags: Md4cFlags(admonitions: true),
            writingDirection: writingDirection,
            layoutDirection: layoutDirection
        )
    }

    /// Base direction of the paragraph containing `text`.
    private func direction(of text: String, in rendered: NSAttributedString) -> NSWritingDirection {
        let range = (rendered.string as NSString).range(of: text)
        guard range.location != NSNotFound else {
            XCTFail("\(text) was not rendered")
            return .natural
        }
        let style = rendered.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle
        return style?.baseWritingDirection ?? .natural
    }

    private func titleDirection(
        _ markdown: String,
        layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight
    ) -> NSWritingDirection {
        direction(of: AdmonitionType.note.title, in: render(markdown, layoutDirection: layoutDirection))
    }

    private func tableAttachment(in rendered: NSAttributedString) -> TableAttachment? {
        var attachment: TableAttachment?
        rendered.enumerateAttribute(.attachment, in: NSRange(location: 0, length: rendered.length)) { value, _, stop in
            if let table = value as? TableAttachment {
                attachment = table
                stop.pointee = true
            }
        }
        return attachment
    }

    @MainActor
    private func renderSynchronously(_ store: MarkdownRenderStore, markdown: String, layoutDirection: LayoutDirection) {
        store.schedule(MarkdownRenderInputs(markdown: markdown, config: config, layoutDirection: layoutDirection))
        let rendered = expectation(description: "render applied")
        let cancellable = store.$source
            .dropFirst()
            .sink { _ in rendered.fulfill() }
        wait(for: [rendered], timeout: 2)
        cancellable.cancel()
    }
}
