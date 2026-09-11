import Combine
import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class SpoilerTests: XCTestCase {
    private var config: MarkdownStyleConfig!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.baseline()
    }

    // MARK: - Rendering

    func testSpoilerConcealsTextAndStashesColor() {
        let result = MarkdownRenderer.render("||hidden|| shown", config: config)

        XCTAssertEqual(result.string.trimmingCharacters(in: .newlines), "hidden shown")
        XCTAssertTrue(MarkdownAttributeValue.boolValue(from: attribute(MarkdownAttribute.spoiler, onWord: "hidden", in: result)))
        XCTAssertEqual(attribute(.foregroundColor, onWord: "hidden", in: result) as? UIColor, .clear)
        XCTAssertEqual(
            attribute(MarkdownAttribute.spoilerOriginalColor, onWord: "hidden", in: result) as? UIColor,
            config.paragraph.foregroundColor
        )

        XCTAssertNil(attribute(MarkdownAttribute.spoiler, onWord: "shown", in: result))
        XCTAssertEqual(attribute(.foregroundColor, onWord: "shown", in: result) as? UIColor, config.paragraph.foregroundColor)
    }

    func testSpoilerIsAlwaysEnabled() {
        XCTAssertNotNil(Parser.shared.parseMarkdown("||hidden||").first(ofType: .spoiler))
    }

    func testWrappersRenderedAfterSpoilerStayConcealed() {
        var styled = config!
        styled.strong.foregroundColor = .systemRed
        styled.link.foregroundColor = .systemBlue

        let strong = MarkdownRenderer.render("**||hidden||**", config: styled)
        XCTAssertEqual(attribute(.foregroundColor, onWord: "hidden", in: strong) as? UIColor, .clear)
        XCTAssertEqual(attribute(MarkdownAttribute.spoilerOriginalColor, onWord: "hidden", in: strong) as? UIColor, .systemRed)

        let link = MarkdownRenderer.render("[||hidden||](https://swmansion.com)", config: styled)
        XCTAssertEqual(attribute(.foregroundColor, onWord: "hidden", in: link) as? UIColor, .clear)
        XCTAssertEqual(attribute(MarkdownAttribute.spoilerOriginalColor, onWord: "hidden", in: link) as? UIColor, .systemBlue)
        XCTAssertNotNil(attribute(.link, onWord: "hidden", in: link))
    }

    func testSpoilerInsideStrongRevealsInStrongColor() {
        var styled = config!
        styled.strong.foregroundColor = .systemRed

        let result = MarkdownRenderer.render("||**hidden**||", config: styled)

        XCTAssertEqual(attribute(.foregroundColor, onWord: "hidden", in: result) as? UIColor, .clear)
        XCTAssertEqual(attribute(MarkdownAttribute.spoilerOriginalColor, onWord: "hidden", in: result) as? UIColor, .systemRed)
    }

    func testCheckedTaskItemRecolorsStashAtRenderAndToggleTime() {
        var styled = config!
        styled.taskList.checkedTextColor = .systemGray

        let rendered = MarkdownRenderer.render("- [x] ||done||", config: styled)
        XCTAssertEqual(attribute(.foregroundColor, onWord: "done", in: rendered) as? UIColor, .clear)
        XCTAssertEqual(attribute(MarkdownAttribute.spoilerOriginalColor, onWord: "done", in: rendered) as? UIColor, .systemGray)

        let unchecked = MarkdownRenderer.render("- [ ] ||todo||", config: styled)
        let toggled = TaskListInteraction.togglingItem(in: unchecked, index: 0, checked: true, config: styled)!
        XCTAssertEqual(attribute(.foregroundColor, onWord: "todo", in: toggled) as? UIColor, .clear)
        XCTAssertEqual(attribute(MarkdownAttribute.spoilerOriginalColor, onWord: "todo", in: toggled) as? UIColor, .systemGray)
    }

    // MARK: - Reveal

    func testRevealingRestoresColorAndKeepsMarkerForCopy() {
        let rendered = MarkdownRenderer.render("||hidden|| shown", config: config)

        let revealed = SpoilerInteraction.revealing(in: rendered, ordinals: [0])!

        XCTAssertFalse(MarkdownAttributeValue.boolValue(from: attribute(MarkdownAttribute.spoiler, onWord: "hidden", in: revealed)))
        XCTAssertNil(attribute(MarkdownAttribute.spoilerOriginalColor, onWord: "hidden", in: revealed))
        XCTAssertEqual(attribute(.foregroundColor, onWord: "hidden", in: revealed) as? UIColor, config.paragraph.foregroundColor)
        XCTAssertEqual(revealed.string, rendered.string)
        XCTAssertEqual(
            MarkdownExtractor.extractMarkdown(from: revealed, in: rangeOfWord("hidden", in: revealed)),
            "||hidden||"
        )
    }

    func testRevealingUnknownOrRevealedOrdinalReturnsNil() {
        let rendered = MarkdownRenderer.render("||hidden|| shown", config: config)
        let revealed = SpoilerInteraction.revealing(in: rendered, ordinals: [0])!

        XCTAssertNil(SpoilerInteraction.revealing(in: rendered, ordinals: [3]))
        XCTAssertNil(SpoilerInteraction.revealing(in: revealed, ordinals: [0]))
    }

    func testOrdinalsCountRevealedSpoilersToo() {
        let rendered = MarkdownRenderer.render("||one|| and ||two||", config: config)

        let first = SpoilerInteraction.revealing(in: rendered, ordinals: [0])!
        XCTAssertEqual(SpoilerInteraction.spoilerRanges(in: first).count, 2)
        XCTAssertEqual(SpoilerInteraction.concealedRanges(in: first), [rangeOfWord("two", in: first)])

        let both = SpoilerInteraction.revealing(in: first, ordinals: [1])!
        XCTAssertTrue(SpoilerInteraction.concealedRanges(in: both).isEmpty)
    }

    func testIsConcealedReportsAnyOverlap() {
        let rendered = MarkdownRenderer.render("||hidden|| shown", config: config)

        XCTAssertTrue(SpoilerInteraction.isConcealed(rangeOfWord("hidden", in: rendered), in: rendered))
        XCTAssertTrue(SpoilerInteraction.isConcealed(NSRange(location: 4, length: 5), in: rendered))
        XCTAssertFalse(SpoilerInteraction.isConcealed(rangeOfWord("shown", in: rendered), in: rendered))
    }

    @MainActor
    func testStoreRevealSurvivesConfigRerenderButNotNewMarkdown() {
        let store = MarkdownRenderStore()
        renderSynchronously(store, markdown: "||hidden|| shown", config: config)

        store.revealSpoiler(in: rangeOfWord("hidden", in: store.attributedText))
        XCTAssertTrue(SpoilerInteraction.concealedRanges(in: store.attributedText).isEmpty)

        // A top margin inserts a spacer character, so the range shifts.
        var shifted = config!
        shifted.paragraph.marginTop = 12
        shifted.paragraph.foregroundColor = .systemRed
        renderSynchronously(store, markdown: "||hidden|| shown", config: shifted)
        XCTAssertTrue(SpoilerInteraction.concealedRanges(in: store.attributedText).isEmpty)
        XCTAssertEqual(attribute(.foregroundColor, onWord: "hidden", in: store.attributedText) as? UIColor, .systemRed)

        renderSynchronously(store, markdown: "||hidden|| changed", config: shifted)
        XCTAssertEqual(SpoilerInteraction.concealedRanges(in: store.attributedText).count, 1)
    }

    // MARK: - Overlays

    @MainActor
    func testOverlaysCoverConcealedSegmentsOnly() {
        let textView = makeLaidOutTextView("||hidden|| shown")
        let hidden = rangeOfWord("hidden", in: textView.attributedText)

        XCTAssertEqual(overlays(in: textView).map(\.charRange), [hidden])
        let hiddenFrame = textView.accessibilityScreenFrame(for: hidden)
        XCTAssertGreaterThan(hiddenFrame.width, 0)
        XCTAssertEqual(overlays(in: textView).first?.frame.width ?? 0, hiddenFrame.width, accuracy: 1)
    }

    @MainActor
    func testWrappedSpoilerGetsOneOverlayPerLine() {
        let words = Array(repeating: "spoiler", count: 30).joined(separator: " ")
        let textView = makeLaidOutTextView("||\(words)||", width: 200)

        XCTAssertGreaterThan(overlays(in: textView).count, 1)
    }

    @MainActor
    func testOverlayModeAndStyleAreApplied() {
        let textView = makeLaidOutTextView("||hidden||")
        XCTAssertTrue(overlays(in: textView).first is ParticleSpoilerOverlayView)

        textView.spoilerOverlays.mode = .solid
        var styled = textView.styleConfig
        styled.spoiler.color = .systemPurple
        styled.spoiler.solidBorderRadius = 9
        textView.styleConfig = styled

        let solid = overlays(in: textView).first as? SolidSpoilerOverlayView
        XCTAssertNotNil(solid)
        XCTAssertEqual(overlays(in: textView).count, 1)
        XCTAssertEqual(solid?.backgroundColor, .systemPurple)
        XCTAssertEqual(solid?.layer.cornerRadius, 9)
    }

    @MainActor
    func testTapHitTestFindsOverlayAndRevealFadesIt() {
        let textView = makeLaidOutTextView("||hidden|| shown")
        let overlay = overlays(in: textView).first!
        let inside = CGPoint(x: overlay.frame.midX, y: overlay.frame.midY)
        let outside = CGPoint(x: overlay.frame.maxX + 40, y: overlay.frame.midY)

        XCTAssertEqual(textView.spoilerOverlays.concealedRange(at: inside), overlay.charRange)
        XCTAssertNil(textView.spoilerOverlays.concealedRange(at: outside))

        textView.spoilerOverlays.reveal(range: overlay.charRange)
        XCTAssertTrue(overlay.isRevealing)

        textView.setMarkdownAttributedText(SpoilerInteraction.revealing(in: textView.attributedText, ordinals: [0])!)
        textView.layoutIfNeeded()
        // The fading overlay is kept until its animation completes; no new one appears.
        XCTAssertEqual(overlays(in: textView), [overlay])
    }

    @MainActor
    func testRevealedTextRemovesOverlays() {
        let textView = makeLaidOutTextView("||hidden|| shown")

        textView.setMarkdownAttributedText(SpoilerInteraction.revealing(in: textView.attributedText, ordinals: [0])!)
        textView.layoutIfNeeded()

        XCTAssertTrue(overlays(in: textView).isEmpty)
    }

    @MainActor
    func testConcealedLinkDoesNotInteract() {
        let textView = makeLaidOutTextView("||[press](https://swmansion.com)|| [open](https://swmansion.com)")
        let coordinator = MarkdownTextViewRepresentable.Coordinator()
        var pressed: [URL] = []
        coordinator.onLinkPress = { pressed.append($0) }
        let url = URL(string: "https://swmansion.com")!

        let hidden = rangeOfWord("press", in: textView.attributedText)
        let visible = rangeOfWord("open", in: textView.attributedText)
        XCTAssertFalse(coordinator.textView(textView, shouldInteractWith: url, in: hidden, interaction: .invokeDefaultAction))
        XCTAssertTrue(pressed.isEmpty)
        XCTAssertFalse(coordinator.textView(textView, shouldInteractWith: url, in: visible, interaction: .invokeDefaultAction))
        XCTAssertEqual(pressed, [url])
    }

    // MARK: - Theme

    func testSpoilerThemeElementAppliesToConfig() {
        var applied = MarkdownStyleConfig()
        Spoiler()
            .color(Color(UIColor.systemPurple))
            .background(Color(UIColor.black))
            .particleDensity(12)
            .particleSpeed(30)
            .solidBorderRadius(6)
            .apply(to: &applied, traitCollection: .current)

        XCTAssertNotNil(applied.spoiler.color)
        XCTAssertNotNil(applied.spoiler.backgroundColor)
        XCTAssertEqual(applied.spoiler.particleDensity, 12)
        XCTAssertEqual(applied.spoiler.particleSpeed, 30)
        XCTAssertEqual(applied.spoiler.solidBorderRadius, 6)
    }

    func testDefaultThemeConfiguresSpoilerOverlayColors() {
        let resolved = MarkdownStyleConfig.resolve(layers: [.default], traitCollection: .current)

        XCTAssertNotNil(resolved.spoiler.color)
        XCTAssertNotNil(resolved.spoiler.backgroundColor)
    }

    func testSpoilerStyleMergeKeepsBaseValues() {
        var base = SpoilerStyle(color: .red, particleDensity: 8)
        base.merge(SpoilerStyle(particleSpeed: 5))

        XCTAssertEqual(base.color, .red)
        XCTAssertEqual(base.particleDensity, 8)
        XCTAssertEqual(base.particleSpeed, 5)
    }

    func testEnvironmentDefaultsToParticles() {
        XCTAssertEqual(EnvironmentValues().markdownSpoilerOverlay, .particles)
    }

    // MARK: - Copy as Markdown

    func testExtractorWrapsSpoilerInPipes() {
        let rendered = MarkdownRenderer.render("Some ||hidden|| text.", config: config)

        XCTAssertEqual(
            MarkdownExtractor.extractMarkdown(from: rendered, in: rangeOfWord("hidden", in: rendered)),
            "||hidden||"
        )
    }

    // MARK: - Helpers

    @MainActor
    private func makeLaidOutTextView(_ markdown: String, width: CGFloat = 320) -> MarkdownTextView {
        let textView = MarkdownTextView()
        textView.frame = CGRect(x: 0, y: 0, width: width, height: 400)
        textView.setMarkdownAttributedText(MarkdownRenderer.render(markdown, config: config))
        textView.layoutIfNeeded()
        return textView
    }

    @MainActor
    private func overlays(in textView: MarkdownTextView) -> [SpoilerOverlayView] {
        textView.subviews.compactMap { $0 as? SpoilerOverlayView }
    }

    @MainActor
    private func renderSynchronously(_ store: MarkdownRenderStore, markdown: String, config: MarkdownStyleConfig) {
        let rendered = expectation(description: "render applied for \(markdown)")
        let cancellable = store.$source
            .dropFirst()
            .sink { _ in rendered.fulfill() }
        store.schedule(markdown: markdown, config: config)
        wait(for: [rendered], timeout: 2)
        cancellable.cancel()
    }

    private func rangeOfWord(_ word: String, in text: NSAttributedString) -> NSRange {
        let range = (text.string as NSString).range(of: word)
        XCTAssertNotEqual(range.location, NSNotFound, "'\(word)' not found in '\(text.string)'")
        return range
    }

    private func attribute(_ key: NSAttributedString.Key, onWord word: String, in text: NSAttributedString) -> Any? {
        let range = rangeOfWord(word, in: text)
        guard range.location != NSNotFound else { return nil }
        return text.attribute(key, at: range.location, effectiveRange: nil)
    }
}
