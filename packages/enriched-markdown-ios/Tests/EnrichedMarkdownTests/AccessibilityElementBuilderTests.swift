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

    private func specs(
        for markdown: String,
        labels: MarkdownAccessibilityLabels = .default
    ) -> [MarkdownAccessibilityElementSpec] {
        MarkdownAccessibilityElementBuilder.specs(for: MarkdownRenderer.render(markdown, config: config), labels: labels)
    }

    func testEmptyStringYieldsNoSpecs() {
        XCTAssertTrue(MarkdownAccessibilityElementBuilder.specs(for: NSAttributedString()).isEmpty)
    }

    // MARK: - Headings

    func testHeadingBecomesSingleHeadingSpec() {
        let result = specs(for: "# Title\n\nBody paragraph")

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].kind, .text)
        XCTAssertEqual(result[0].headingLevel, 1)
        XCTAssertEqual(result[0].label, "Title")
        XCTAssertEqual(result[1].kind, .text)
        XCTAssertNil(result[1].headingLevel)
        XCTAssertEqual(result[1].label, "Body paragraph")
    }

    func testHeadingLevelsAreReported() {
        let result = specs(for: "### Third level")

        XCTAssertEqual(result.first?.headingLevel, 3)
    }

    func testLinkInsideHeadingStaysNavigableAndKeepsLevel() {
        let result = specs(for: "# Hello [world](https://w.example) again")

        XCTAssertEqual(result.map(\.label), ["Hello", "world", "again"])
        XCTAssertEqual(result[1].kind, .link(URL(string: "https://w.example")!))
        XCTAssertEqual(result.map(\.headingLevel), [1, 1, 1])
    }

    func testHeadingThatIsEntirelyALinkIsALinkWithHeadingLevel() {
        let result = specs(for: "## [Docs](https://d.example)")

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].kind, .link(URL(string: "https://d.example")!))
        XCTAssertEqual(result[0].headingLevel, 2)
    }

    // MARK: - Paragraphs, links, images

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
        XCTAssertEqual(result[0].kind, .image(link: nil))
        XCTAssertEqual(result[0].label, "company logo")
    }

    func testImageWithoutAltTextFallsBackToImage() {
        let result = specs(for: "![](https://example.invalid/logo.png)")

        XCTAssertEqual(result.first?.kind, .image(link: nil))
        XCTAssertEqual(result.first?.label, "Image")
    }

    func testLinkedImageKeepsAltTextAndCarriesLinkTarget() {
        let result = specs(for: "[![Logo](https://example.invalid/logo.png)](https://swmansion.com)")

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].kind, .image(link: URL(string: "https://swmansion.com")!))
        XCTAssertEqual(result[0].label, "Logo")
    }

    func testInlineLinkedImageSplitsSurroundingText() {
        let result = specs(for: "See [![Logo](https://example.invalid/logo.png)](https://swmansion.com) here")

        XCTAssertEqual(result.map(\.label), ["See", "Logo", "here"])
        XCTAssertEqual(result[1].kind, .image(link: URL(string: "https://swmansion.com")!))
    }

    func testLinkWrappingTextAndImageSplitsAroundTheImage() {
        let result = specs(for: "[docs ![Logo](https://example.invalid/logo.png) site](https://swmansion.com)")
        let target = URL(string: "https://swmansion.com")!

        XCTAssertEqual(result.map(\.label), ["docs", "Logo", "site"])
        XCTAssertEqual(result[0].kind, .link(target))
        XCTAssertEqual(result[1].kind, .image(link: target))
        XCTAssertEqual(result[2].kind, .link(target))
    }

    // MARK: - Attachments

    func testLabelledAttachmentBecomesItsOwnElement() {
        let text = NSMutableAttributedString(string: "Euler says ")
        let formula = NSTextAttachment()
        formula.accessibilityLabel = "Math: e^{i\\pi}"
        text.append(NSAttributedString(attachment: formula))
        text.append(NSAttributedString(string: " is neat."))

        let result = MarkdownAccessibilityElementBuilder.specs(for: text)

        XCTAssertEqual(result.map(\.label), ["Euler says", "Math: e^{i\\pi}", "is neat."])
        XCTAssertEqual(result[1].kind, .text)
    }

    func testUnlabelledAttachmentIsNotSpokenAsReplacementCharacter() {
        let text = NSMutableAttributedString(string: "before ")
        text.append(NSAttributedString(attachment: NSTextAttachment()))
        text.append(NSAttributedString(string: " after"))

        let result = MarkdownAccessibilityElementBuilder.specs(for: text)

        XCTAssertEqual(result.map(\.label), ["before  after"])
    }

    // MARK: - Code blocks

    func testCodeBlockIsOneElementWithTheCodeAsLabel() {
        let result = specs(for: "Intro\n\n```swift\nlet a = 1\nlet b = 2\n```\n\nOutro")

        XCTAssertEqual(result.map(\.label), ["Intro", "let a = 1\nlet b = 2", "Outro"])
        XCTAssertEqual(result[1].kind, .codeBlock(copyAction: "Copy code"))
    }

    // MARK: - Lists

    func testUnorderedListItemsAnnounceBulletPoint() {
        let result = specs(for: "- one\n- two")

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].value, "Bullet point")
        XCTAssertEqual(result[1].value, "Bullet point")
    }

    func testOrderedListItemsAnnouncePosition() {
        let result = specs(for: "1. one\n2. two\n3. three")

        XCTAssertEqual(result.map(\.value), ["List item 1", "List item 2", "List item 3"])
    }

    func testNestedListItemsAnnounceNesting() {
        let result = specs(for: "- outer\n  - inner")

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].value, "Bullet point")
        XCTAssertEqual(result[1].value, "Nested bullet point")
    }

    func testTaskListItemsAnnounceCheckedState() {
        let result = specs(for: "- [x] done\n- [ ] todo")

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].value, "Task, checked")
        XCTAssertEqual(result[1].value, "Task, not checked")
    }

    func testNestedTaskItemsAnnounceNesting() {
        let result = specs(for: "- outer\n  - [ ] inner task")

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[1].value, "Nested task, not checked")
    }

    func testLinkInsideListItemCarriesListContext() {
        let result = specs(for: "- see [docs](https://d.example) here")

        XCTAssertEqual(result.first { $0.kind == .link(URL(string: "https://d.example")!) }?.value, "Bullet point")
    }

    func testNonListParagraphHasNoAnnouncement() {
        let result = specs(for: "Plain paragraph")

        XCTAssertNil(result.first?.value)
    }

    // MARK: - Blockquotes

    func testBlockquoteContentAnnouncesBlockquote() {
        let result = specs(for: "> quoted words")

        XCTAssertEqual(result.first?.label, "quoted words")
        XCTAssertEqual(result.first?.value, "Blockquote")
    }

    func testNestedBlockquoteAnnouncesNesting() {
        let result = specs(for: "> outer\n>\n> > inner")

        XCTAssertEqual(result.map(\.value), ["Blockquote", "Nested blockquote"])
    }

    func testListInsideBlockquoteAnnouncesBoth() {
        let result = specs(for: "> - item")

        XCTAssertEqual(result.first?.value, "Bullet point, Blockquote")
    }

    // MARK: - Custom labels

    func testCustomLabelsReplaceDefaults() {
        var labels = MarkdownAccessibilityLabels()
        labels.list.top.bulletPoint = "Punkt"
        labels.list.nested.orderedItem = "Unterelement {n}"
        labels.blockquote.quote = "Zitat"
        labels.image.fallback = "Bild"

        XCTAssertEqual(specs(for: "- eins", labels: labels).first?.value, "Punkt")
        XCTAssertEqual(specs(for: "- eins\n  1. zwei", labels: labels).last?.value, "Unterelement 1")
        XCTAssertEqual(specs(for: "> Wort", labels: labels).first?.value, "Zitat")
        XCTAssertEqual(specs(for: "![](https://example.invalid/a.png)", labels: labels).first?.label, "Bild")
    }

    func testTableRowLabelUsesTemplate() {
        var labels = MarkdownAccessibilityLabels()
        labels.table.row = "Zeile {n}: {content}"

        let result = specs(for: "| A | B |\n|---|---|\n| 1 | 2 |", labels: labels)

        XCTAssertEqual(result.map(\.label), ["Zeile 1: A, B", "Zeile 2: 1, 2"])
    }
}

final class MarkdownTextViewAccessibilityTests: XCTestCase {
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

    private func elements(of textView: MarkdownTextView) -> [MarkdownAccessibilityElement] {
        textView.accessibilityElements?.compactMap { $0 as? MarkdownAccessibilityElement } ?? []
    }

    func testElementsReplaceHostAccessibility() {
        let textView = makeTextView(markdown: "# Title\n\nBody")

        XCTAssertFalse(textView.isAccessibilityElement)
        XCTAssertEqual((textView.accessibilityElements ?? []).count, 2)
    }

    func testHeadingElementCarriesHeaderTrait() {
        let textView = makeTextView(markdown: "## Section")

        let element = elements(of: textView).first
        XCTAssertNotNil(element)
        XCTAssertTrue(element!.accessibilityTraits.contains(.header))
        XCTAssertEqual(element!.accessibilityLabel, "Section")
        let level = element!.accessibilityAttributedLabel?.attribute(
            .accessibilityTextHeadingLevel,
            at: 0,
            effectiveRange: nil
        ) as? Int
        XCTAssertEqual(level, 2)
    }

    func testLinkInsideHeadingIsAnActivatableHeaderLink() {
        let textView = makeTextView(markdown: "## [Docs](https://swmansion.com)")

        let link = elements(of: textView).first
        XCTAssertEqual(link?.url, URL(string: "https://swmansion.com"))
        XCTAssertTrue(link!.accessibilityTraits.contains(.link))
        XCTAssertTrue(link!.accessibilityTraits.contains(.header))
    }

    func testLinkElementActivatesPressHandler() {
        let textView = makeTextView(markdown: "[press me](https://swmansion.com)")
        var pressedURL: URL?
        textView.onLinkPress = { pressedURL = $0 }

        XCTAssertEqual(elements(of: textView).first?.accessibilityActivate(), true)
        XCTAssertEqual(pressedURL, URL(string: "https://swmansion.com"))
    }

    func testLinkElementWithoutHandlerDoesNotActivate() {
        let textView = makeTextView(markdown: "[press me](https://swmansion.com)")

        XCTAssertEqual(elements(of: textView).first?.accessibilityActivate(), false)
    }

    func testPlainTextElementDoesNotActivate() {
        let textView = makeTextView(markdown: "plain")
        textView.onLinkPress = { _ in XCTFail("no link to press") }

        XCTAssertEqual(elements(of: textView).first?.accessibilityActivate(), false)
    }

    func testLinkedImageIsAnActivatableImageLink() {
        let textView = makeTextView(markdown: "[![Logo](https://example.invalid/logo.png)](https://swmansion.com)")
        var pressedURL: URL?
        textView.onLinkPress = { pressedURL = $0 }

        let image = elements(of: textView).first
        XCTAssertEqual(image?.accessibilityLabel, "Logo")
        XCTAssertTrue(image!.accessibilityTraits.contains(.image))
        XCTAssertTrue(image!.accessibilityTraits.contains(.link))
        XCTAssertTrue(image!.accessibilityActivate())
        XCTAssertEqual(pressedURL, URL(string: "https://swmansion.com"))
    }

    func testCodeBlockOffersCopyCustomAction() {
        let textView = makeTextView(markdown: "```\nlet a = 1\n```")

        let block = elements(of: textView).first
        let copy = block?.accessibilityCustomActions?.first
        XCTAssertEqual(copy?.name, "Copy code")
        XCTAssertEqual(copy?.actionHandler?(copy!), true)
        XCTAssertEqual(pasteboard.string, "let a = 1")
    }

    func testRotorsCoverHeadingsLinksAndImages() {
        let textView = makeTextView(
            markdown: "# Title\n\n[link](https://swmansion.com)\n\n![Logo](https://example.invalid/logo.png)"
        )

        XCTAssertEqual(textView.accessibilityCustomRotors?.map(\.name), ["Headings", "Links", "Images"])
    }

    func testRotorsAreOnlyOfferedWhenTheyHaveTargets() {
        let textView = makeTextView(markdown: "Plain paragraph\n\n[link](https://swmansion.com)")

        XCTAssertEqual(textView.accessibilityCustomRotors?.map(\.name), ["Links"])
    }

    func testRotorWalksItsElementsInBothDirections() {
        let textView = makeTextView(markdown: "# One\n\n## Two")
        guard let rotor = textView.accessibilityCustomRotors?.first else { return XCTFail("no rotor") }
        let headings = elements(of: textView)

        let predicate = UIAccessibilityCustomRotorSearchPredicate()
        predicate.searchDirection = .next
        let first = rotor.itemSearchBlock(predicate)?.targetElement as? MarkdownAccessibilityElement
        XCTAssertTrue(first === headings[0])

        predicate.currentItem = UIAccessibilityCustomRotorItemResult(targetElement: headings[0], targetRange: nil)
        let second = rotor.itemSearchBlock(predicate)?.targetElement as? MarkdownAccessibilityElement
        XCTAssertTrue(second === headings[1])

        predicate.currentItem = UIAccessibilityCustomRotorItemResult(targetElement: headings[1], targetRange: nil)
        XCTAssertNil(rotor.itemSearchBlock(predicate))

        predicate.searchDirection = .previous
        let back = rotor.itemSearchBlock(predicate)?.targetElement as? MarkdownAccessibilityElement
        XCTAssertTrue(back === headings[0])
    }

    func testChangingLabelsRebuildsElementsAndRotors() {
        let textView = makeTextView(markdown: "- item\n\n# Title")
        var labels = MarkdownAccessibilityLabels()
        labels.list.top.bulletPoint = "Punkt"
        labels.rotor.headings = "Überschriften"

        textView.accessibilityLabels = labels

        XCTAssertEqual(elements(of: textView).first?.accessibilityValue, "Punkt")
        XCTAssertEqual(textView.accessibilityCustomRotors?.map(\.name), ["Überschriften"])
    }

    func testEmptyContentKeepsDefaultAccessibility() {
        let textView = MarkdownTextView()
        textView.setMarkdownAttributedText(NSAttributedString())

        XCTAssertTrue((textView.accessibilityElements as? [UIAccessibilityElement])?.isEmpty ?? true)
    }
}
