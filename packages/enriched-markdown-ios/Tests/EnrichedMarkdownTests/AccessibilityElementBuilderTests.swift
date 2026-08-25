import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class AccessibilityElementBuilderTests: XCTestCase {
    private var config: MarkdownStyleConfig!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.resolve(layers: [.default], traitCollection: .current)
    }

    private func specs(for markdown: String) -> [MarkdownAccessibilityElementSpec] {
        MarkdownAccessibilityElementBuilder.specs(for: MarkdownRenderer.render(markdown, config: config))
    }

    func testEmptyStringYieldsNoSpecs() {
        XCTAssertTrue(MarkdownAccessibilityElementBuilder.specs(for: NSAttributedString()).isEmpty)
    }

    func testHeadingBecomesSingleHeadingSpec() {
        let result = specs(for: "# Title\n\nBody paragraph")

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].kind, .heading(level: 1))
        XCTAssertEqual(result[0].label, "Title")
        XCTAssertEqual(result[1].kind, .text)
        XCTAssertEqual(result[1].label, "Body paragraph")
    }

    func testHeadingLevelsAreReported() {
        let result = specs(for: "### Third level")

        XCTAssertEqual(result.first?.kind, .heading(level: 3))
    }

    func testSpacerParagraphsAreSkipped() {
        let result = specs(for: "First\n\nSecond\n\nThird")

        XCTAssertEqual(result.map(\.label), ["First", "Second", "Third"])
    }

    func testLinksInterleaveWithText() {
        let result = specs(for: "Start [alpha](https://a.example) middle [beta](https://b.example) end")

        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(result[0].kind, .text)
        XCTAssertEqual(result[0].label, "Start")
        XCTAssertEqual(result[1].kind, .link(URL(string: "https://a.example")!))
        XCTAssertEqual(result[1].label, "alpha")
        XCTAssertEqual(result[2].label, "middle")
        XCTAssertEqual(result[3].kind, .link(URL(string: "https://b.example")!))
        XCTAssertEqual(result[4].label, "end")
    }

    func testImageUsesAltTextAsLabel() {
        let result = specs(for: "![company logo](https://example.invalid/logo.png)")

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].kind, .image)
        XCTAssertEqual(result[0].label, "company logo")
    }

    func testImageWithoutAltTextFallsBackToImage() {
        let result = specs(for: "![](https://example.invalid/logo.png)")

        XCTAssertEqual(result.first?.kind, .image)
        XCTAssertEqual(result.first?.label, "Image")
    }

    func testUnorderedListItemsAnnounceBulletPoint() {
        let result = specs(for: "- one\n- two")

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].listAnnouncement, "bullet point")
        XCTAssertEqual(result[1].listAnnouncement, "bullet point")
    }

    func testOrderedListItemsAnnouncePosition() {
        let result = specs(for: "1. one\n2. two\n3. three")

        XCTAssertEqual(result.map(\.listAnnouncement), ["list item 1", "list item 2", "list item 3"])
    }

    func testNestedListItemsAnnounceNesting() {
        let result = specs(for: "- outer\n  - inner")

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].listAnnouncement, "bullet point")
        XCTAssertEqual(result[1].listAnnouncement, "nested bullet point")
    }

    func testTaskListItemsAnnounceCheckedState() {
        let result = specs(for: "- [x] done\n- [ ] todo")

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].listAnnouncement, "task, checked")
        XCTAssertEqual(result[1].listAnnouncement, "task, not checked")
    }

    func testNestedTaskItemsAnnounceNesting() {
        let result = specs(for: "- outer\n  - [ ] inner task")

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[1].listAnnouncement, "nested task, not checked")
    }

    func testLinkInsideListItemCarriesListContext() {
        let result = specs(for: "- see [docs](https://d.example) here")

        let link = result.first { spec in
            if case .link = spec.kind { return true }
            return false
        }
        XCTAssertEqual(link?.listAnnouncement, "bullet point")
    }

    func testNonListParagraphHasNoAnnouncement() {
        let result = specs(for: "Plain paragraph")

        XCTAssertNil(result.first?.listAnnouncement)
    }

    func testBlockquoteContentIsStillRepresented() {
        let result = specs(for: "> quoted words")

        XCTAssertEqual(result.first?.label, "quoted words")
    }
}

final class MarkdownTextViewAccessibilityTests: XCTestCase {
    private var config: MarkdownStyleConfig!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.resolve(layers: [.default], traitCollection: .current)
    }

    private func makeTextView(markdown: String) -> MarkdownTextView {
        let textView = MarkdownTextView()
        textView.setMarkdownAttributedText(MarkdownRenderer.render(markdown, config: config))
        return textView
    }

    func testElementsReplaceHostAccessibility() {
        let textView = makeTextView(markdown: "# Title\n\nBody")

        XCTAssertFalse(textView.isAccessibilityElement)
        XCTAssertEqual((textView.accessibilityElements ?? []).count, 2)
    }

    func testHeadingElementCarriesHeaderTrait() {
        let textView = makeTextView(markdown: "## Section")

        let element = textView.accessibilityElements?.first as? MarkdownAccessibilityElement
        XCTAssertNotNil(element)
        XCTAssertTrue(element!.accessibilityTraits.contains(.header))
        XCTAssertEqual(element!.accessibilityLabel, "Section")
    }

    func testLinkElementActivatesPressHandler() {
        let textView = makeTextView(markdown: "[press me](https://swmansion.com)")
        var pressedURL: URL?
        textView.onLinkPress = { pressedURL = $0 }

        let link = textView.accessibilityElements?
            .compactMap { $0 as? MarkdownLinkAccessibilityElement }
            .first
        XCTAssertNotNil(link)
        XCTAssertTrue(link!.accessibilityActivate())
        XCTAssertEqual(pressedURL, URL(string: "https://swmansion.com"))
    }

    func testLinkElementWithoutHandlerDoesNotActivate() {
        let textView = makeTextView(markdown: "[press me](https://swmansion.com)")

        let link = textView.accessibilityElements?
            .compactMap { $0 as? MarkdownLinkAccessibilityElement }
            .first
        XCTAssertEqual(link?.accessibilityActivate(), false)
    }

    func testEmptyContentKeepsDefaultAccessibility() {
        let textView = MarkdownTextView()
        textView.setMarkdownAttributedText(NSAttributedString())

        XCTAssertTrue((textView.accessibilityElements as? [UIAccessibilityElement])?.isEmpty ?? true)
    }
}
