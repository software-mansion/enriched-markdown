import Combine
import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class SpoilerTests: XCTestCase {
    private var config: MarkdownStyleConfiguration!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfiguration.baseline()
    }

    // MARK: - Rendering

    func testSpoilerConcealsTextAndStashesColor() throws {
        let result = MarkdownRenderer.render("||hidden|| shown", config: config)

        XCTAssertEqual(result.string.trimmingCharacters(in: .newlines), "hidden shown")
        XCTAssertTrue(MarkdownAttributeValue.boolValue(from: try attribute(MarkdownAttribute.spoiler, onWord: "hidden", in: result)))
        try assertConcealed("hidden", in: result, stashing: config.paragraph.foregroundColor)

        XCTAssertNil(try attribute(MarkdownAttribute.spoiler, onWord: "shown", in: result))
        XCTAssertEqual(try color(onWord: "shown", in: result), config.paragraph.foregroundColor)
    }

    func testSpoilerIsAlwaysEnabled() {
        XCTAssertNotNil(Parser.shared.parseMarkdown("||hidden||").first(ofType: .spoiler))
    }

    func testConcealmentSurvivesWrappersInEitherOrder() throws {
        var styled = config!
        styled.strong.foregroundColor = .systemRed
        styled.link.foregroundColor = .systemBlue

        try assertConcealed("hidden", in: MarkdownRenderer.render("**||hidden||**", config: styled), stashing: .systemRed)
        try assertConcealed("hidden", in: MarkdownRenderer.render("||**hidden**||", config: styled), stashing: .systemRed)
        try assertConcealed(
            "hidden",
            in: MarkdownRenderer.render("[||hidden||](https://swmansion.com)", config: styled),
            stashing: .systemBlue
        )
    }

    func testCheckedTaskItemRecolorsStashAtRenderAndToggleTime() throws {
        var styled = config!
        styled.taskList.checkedTextColor = .systemGray

        try assertConcealed("done", in: MarkdownRenderer.render("- [x] ||done||", config: styled), stashing: .systemGray)

        let unchecked = MarkdownRenderer.render("- [ ] ||todo||", config: styled)
        let toggled = try XCTUnwrap(TaskListInteraction.togglingItem(in: unchecked, index: 0, checked: true, config: styled))
        try assertConcealed("todo", in: toggled, stashing: .systemGray)
    }

    // MARK: - Reveal

    func testRevealingRestoresColorAndKeepsMarkerForCopy() throws {
        let rendered = MarkdownRenderer.render("||hidden|| shown", config: config)

        let revealed = try XCTUnwrap(SpoilerInteraction.revealing(in: rendered, ordinals: [0]))

        XCTAssertFalse(MarkdownAttributeValue.boolValue(from: try attribute(MarkdownAttribute.spoiler, onWord: "hidden", in: revealed)))
        XCTAssertNil(try attribute(MarkdownAttribute.spoilerOriginalColors, onWord: "hidden", in: revealed))
        XCTAssertEqual(try color(onWord: "hidden", in: revealed), config.paragraph.foregroundColor)
        XCTAssertEqual(
            MarkdownExtractor.extractMarkdown(from: revealed, in: try rangeOfWord("hidden", in: revealed)),
            "||hidden||"
        )
    }

    func testRevealingUnknownOrRevealedOrdinalReturnsNil() throws {
        let rendered = MarkdownRenderer.render("||hidden|| shown", config: config)
        let revealed = try XCTUnwrap(SpoilerInteraction.revealing(in: rendered, ordinals: [0]))

        XCTAssertNil(SpoilerInteraction.revealing(in: rendered, ordinals: [3]))
        XCTAssertNil(SpoilerInteraction.revealing(in: revealed, ordinals: [0]))
    }

    func testOrdinalsCountRevealedSpoilersToo() throws {
        let rendered = MarkdownRenderer.render("||one|| and ||two||", config: config)

        let first = try XCTUnwrap(SpoilerInteraction.revealing(in: rendered, ordinals: [0]))
        XCTAssertEqual(SpoilerInteraction.spoilerRanges(in: first).count, 2)
        XCTAssertEqual(SpoilerInteraction.concealedRanges(in: first), [try rangeOfWord("two", in: first)])

        let both = try XCTUnwrap(SpoilerInteraction.revealing(in: first, ordinals: [1]))
        XCTAssertTrue(SpoilerInteraction.concealedRanges(in: both).isEmpty)
    }

    @MainActor
    func testStoreRevealSurvivesConfigRerenderButNotNewMarkdown() throws {
        let store = MarkdownRenderStore()
        renderSynchronously(store, markdown: "||hidden|| shown", config: config)

        store.revealSpoiler(in: try rangeOfWord("hidden", in: store.attributedText))
        XCTAssertTrue(SpoilerInteraction.concealedRanges(in: store.attributedText).isEmpty)

        // A top margin inserts a spacer character, so the range shifts.
        var shifted = config!
        shifted.paragraph.marginTop = 12
        shifted.paragraph.foregroundColor = .systemRed
        renderSynchronously(store, markdown: "||hidden|| shown", config: shifted)
        XCTAssertTrue(SpoilerInteraction.concealedRanges(in: store.attributedText).isEmpty)
        XCTAssertEqual(try color(onWord: "hidden", in: store.attributedText), .systemRed)

        renderSynchronously(store, markdown: "||hidden|| changed", config: shifted)
        XCTAssertEqual(SpoilerInteraction.concealedRanges(in: store.attributedText).count, 1)
    }

    // MARK: - Overlays

    @MainActor
    func testOverlaysCoverConcealedSegmentsOnly() throws {
        let textView = makeLaidOutTextView("||hidden|| shown")
        let hidden = try rangeOfWord("hidden", in: textView.attributedText)

        XCTAssertEqual(overlays(in: textView).map(\.charRange), [hidden])
        let hiddenFrame = textView.accessibilityScreenFrame(for: hidden)
        XCTAssertGreaterThan(hiddenFrame.width, 0)
        XCTAssertEqual(overlays(in: textView).first?.frame.width ?? 0, hiddenFrame.width, accuracy: 1)

        try revealFirstSpoiler(in: textView)
        XCTAssertTrue(overlays(in: textView).isEmpty)
    }

    @MainActor
    func testWrappedSpoilerGetsOneOverlayPerLineCarryingItsText() throws {
        let words = Array(repeating: "spoiler", count: 30).joined(separator: " ")
        let textView = makeLaidOutTextView("||\(words)||", width: 200)

        let segments = overlays(in: textView)
        XCTAssertGreaterThan(segments.count, 1)
        XCTAssertEqual(segments.map(\.concealedText.string).joined(), words)

        let text = try XCTUnwrap(segments.first).concealedText
        XCTAssertEqual(text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, config.paragraph.foregroundColor)
        XCTAssertNil(text.attribute(.paragraphStyle, at: 0, effectiveRange: nil))
    }

    @MainActor
    func testOverlaysCarryBaselineAndReadingOrder() throws {
        config.paragraph.lineHeight = 32
        let words = Array(repeating: "spoiler", count: 30).joined(separator: " ")
        let textView = makeLaidOutTextView("||\(words)||", width: 200)

        let segments = overlays(in: textView).sorted { $0.frame.minY < $1.frame.minY }
        XCTAssertGreaterThan(segments.count, 1)
        XCTAssertEqual(segments.map(\.segmentIndex), Array(segments.indices))
        XCTAssertEqual(Set(segments.map(\.segmentCount)), [segments.count])
        // With a theme line height the typographic baseline can sit at the
        // very bottom of the segment; the baseline offset lifts the glyphs.
        for segment in segments {
            XCTAssertGreaterThan(segment.baseline, 0)
            XCTAssertLessThanOrEqual(segment.baseline, segment.bounds.height)
        }
    }

    /// A theme line height taller than the font is the case where drawing
    /// the slice at the view's origin drifts from the real glyphs.
    @MainActor
    func testConcealedTextImageLinesUpWithRevealedGlyphs() throws {
        config.paragraph.lineHeight = 32
        let textView = makeLaidOutTextView("Shown ||hidden ghosts jump|| after")
        let overlay = try XCTUnwrap(overlays(in: textView).first)
        let frame = overlay.frame
        let drawn = try XCTUnwrap(inkBounds(of: overlay.concealedTextImage(), in: CGRect(origin: .zero, size: frame.size)))

        try revealFirstSpoiler(in: textView)
        let rendered = UIGraphicsImageRenderer(bounds: textView.bounds).image { context in
            textView.layer.render(in: context.cgContext)
        }
        let real = try XCTUnwrap(inkBounds(of: rendered, in: frame))

        XCTAssertEqual(drawn.minY, real.minY, accuracy: 1)
        XCTAssertEqual(drawn.maxY, real.maxY, accuracy: 1)
        XCTAssertEqual(drawn.minX, real.minX, accuracy: 1)
        XCTAssertEqual(drawn.maxX, real.maxX, accuracy: 1)
    }

    @MainActor
    func testOverlayChoiceAndStyleAreApplied() throws {
        let textView = makeLaidOutTextView("||hidden||")
        XCTAssertTrue(overlays(in: textView).first is ParticleSpoilerOverlayView)

        textView.spoilerOverlays.provider = .solid
        var styled = textView.styleConfig
        styled.spoiler.color = .systemPurple
        styled.spoiler.solidCornerRadius = 9
        textView.styleConfig = styled

        let solid = try XCTUnwrap(overlays(in: textView).first as? SolidSpoilerOverlayView)
        XCTAssertEqual(overlays(in: textView).count, 1)
        XCTAssertEqual(solid.backgroundColor, .systemPurple)
        XCTAssertEqual(solid.layer.cornerRadius, 9)
    }

    @MainActor
    func testTapHitTestFindsOverlayAndRevealFadesIt() throws {
        let textView = makeLaidOutTextView("||hidden|| shown")
        let overlay = try XCTUnwrap(overlays(in: textView).first)
        let inside = CGPoint(x: overlay.frame.midX, y: overlay.frame.midY)
        let outside = CGPoint(x: overlay.frame.maxX + 40, y: overlay.frame.midY)

        XCTAssertEqual(textView.spoilerOverlays.concealedRange(at: inside), overlay.charRange)
        XCTAssertNil(textView.spoilerOverlays.concealedRange(at: outside))

        textView.spoilerOverlays.reveal(range: overlay.charRange)
        XCTAssertTrue(overlay.isRevealing)

        try revealFirstSpoiler(in: textView)
        // The fading overlay is kept until its animation completes; no new one appears.
        XCTAssertEqual(overlays(in: textView), [overlay])
    }

    // MARK: - Links

    func testConcealedLinkIsNotALinkUntilRevealed() throws {
        var styled = config!
        styled.link.foregroundColor = .systemBlue
        let url = try XCTUnwrap(URL(string: "https://swmansion.com"))

        let rendered = MarkdownRenderer.render("||[press](https://swmansion.com)||", config: styled)
        XCTAssertNil(try attribute(.link, onWord: "press", in: rendered))
        XCTAssertEqual(try attribute(MarkdownAttribute.spoilerLink, onWord: "press", in: rendered) as? URL, url)
        XCTAssertEqual(try attribute(.underlineColor, onWord: "press", in: rendered) as? UIColor, .clear)
        XCTAssertTrue(MarkdownAccessibilityElementBuilder.specs(for: rendered).allSatisfy { $0.kind != .link(url) })

        let revealed = try XCTUnwrap(SpoilerInteraction.revealing(in: rendered, ordinals: [0]))
        XCTAssertEqual(try attribute(.link, onWord: "press", in: revealed) as? URL, url)
        XCTAssertNil(try attribute(MarkdownAttribute.spoilerLink, onWord: "press", in: revealed))
        XCTAssertEqual(try attribute(.underlineColor, onWord: "press", in: revealed) as? UIColor, .systemBlue)
    }

    func testConcealedLinkStillCopiesAsMarkdownAndHTML() throws {
        let rendered = MarkdownRenderer.render("See ||[press](https://swmansion.com)|| now.", config: config)
        let range = try rangeOfWord("press", in: rendered)

        XCTAssertEqual(
            MarkdownExtractor.extractMarkdown(from: rendered, in: range),
            "||[press](https://swmansion.com)||"
        )
        XCTAssertTrue(
            MarkdownHTMLGenerator.generateHTML(from: rendered, in: range, config: config)
                .contains("href=\"https://swmansion.com\"")
        )
    }

    // MARK: - Custom providers

    @MainActor
    func testCustomProviderBuildsOverlaysFromSpoilerStyle() {
        let textView = makeLaidOutTextView("||hidden||")
        var styled = textView.styleConfig
        styled.spoiler.color = .systemPurple
        textView.styleConfig = styled

        textView.spoilerOverlays.provider = TintOverlayProvider()

        let tinted = overlays(in: textView).first
        XCTAssertTrue(tinted is TintOverlayView)
        XCTAssertEqual(tinted?.backgroundColor, .systemPurple)
    }

    @MainActor
    func testProviderEqualityDecidesRebuild() {
        let textView = makeLaidOutTextView("||hidden||")
        textView.spoilerOverlays.provider = TintOverlayProvider(fallback: .red)
        let first = overlays(in: textView).first

        textView.spoilerOverlays.provider = TintOverlayProvider(fallback: .red)
        XCTAssertTrue(overlays(in: textView).first === first)

        textView.spoilerOverlays.provider = TintOverlayProvider(fallback: .blue)
        XCTAssertFalse(overlays(in: textView).first === first)
    }

    @MainActor
    func testCustomRevealAnimationRemovesOverlayOnCompletion() throws {
        let textView = makeLaidOutTextView("||hidden||")
        textView.spoilerOverlays.provider = TintOverlayProvider()
        let overlay = try XCTUnwrap(overlays(in: textView).first)

        textView.spoilerOverlays.reveal(range: overlay.charRange)

        XCTAssertTrue(overlays(in: textView).isEmpty)
    }

    // MARK: - Theme

    func testSpoilerThemeElementAppliesToConfig() {
        var applied = MarkdownStyleConfiguration()
        Spoiler()
            .foregroundStyle(Color(UIColor.systemPurple))
            .background(Color(UIColor.black))
            .apply(to: &applied, traitCollection: .current)

        XCTAssertNotNil(applied.spoiler.color)
        XCTAssertNotNil(applied.spoiler.backgroundColor)
    }

    // MARK: - Overlay tuning

    @MainActor
    func testProviderTuningWinsOverThemeAndDefaults() throws {
        var style = SpoilerStyle()
        style.particleDensity = 3
        style.solidCornerRadius = 9

        let tuned = try XCTUnwrap(
            ParticleSpoilerOverlayProvider.particles(density: 12, speed: 30)
                .makeOverlay(charRange: NSRange(location: 0, length: 1), style: style) as? ParticleSpoilerOverlayView
        )
        XCTAssertEqual(tuned.density, 12)
        XCTAssertEqual(tuned.speed, 30)

        let themed = try XCTUnwrap(
            ParticleSpoilerOverlayProvider.particles
                .makeOverlay(charRange: NSRange(location: 0, length: 1), style: style) as? ParticleSpoilerOverlayView
        )
        XCTAssertEqual(themed.density, 3, "the theme's value is the fallback")
        XCTAssertEqual(themed.speed, ParticleSpoilerOverlayView.defaultSpeed)

        let solid = SolidSpoilerOverlayProvider.solid(cornerRadius: 6)
            .makeOverlay(charRange: NSRange(location: 0, length: 1), style: style)
        XCTAssertEqual(solid.layer.cornerRadius, 6)
        XCTAssertEqual(
            SolidSpoilerOverlayProvider.solid.makeOverlay(charRange: NSRange(location: 0, length: 1), style: style)
                .layer.cornerRadius,
            9
        )
    }

    func testTunedProvidersCompareByTheirParameters() {
        XCTAssertNotEqual(ParticleSpoilerOverlayProvider.particles(density: 1), .particles)
        XCTAssertEqual(ParticleSpoilerOverlayProvider.particles(density: 1), .particles(density: 1))
        XCTAssertTrue(SolidSpoilerOverlayProvider.solid(cornerRadius: 2).isEqual(to: SolidSpoilerOverlayProvider(cornerRadius: 2)))
        XCTAssertFalse(SolidSpoilerOverlayProvider.solid.isEqual(to: ParticleSpoilerOverlayProvider.particles))
    }

    func testDefaultThemeConfiguresSpoilerOverlayColors() {
        let resolved = MarkdownStyleConfiguration.resolve(layers: [.default], traitCollection: .current)

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
        XCTAssertTrue(EnvironmentValues().markdownSpoilerOverlay is ParticleSpoilerOverlayProvider)
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

    /// Bounding box, in points relative to `rect`'s origin, of the pixels in
    /// `rect` that are more than faintly opaque; nil when there are none.
    private func inkBounds(of image: UIImage, in rect: CGRect) -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }
        let scale = image.scale
        let width = cgImage.width, height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        let columns = max(0, Int(rect.minX * scale))..<min(width, Int(rect.maxX * scale))
        let rows = max(0, Int(rect.minY * scale))..<min(height, Int(rect.maxY * scale))
        var minX = Int.max, maxX = -1, minY = Int.max, maxY = -1
        for row in rows {
            for column in columns where pixels[(row * width + column) * 4 + 3] > 64 {
                minX = min(minX, column); maxX = max(maxX, column)
                minY = min(minY, row); maxY = max(maxY, row)
            }
        }
        guard maxX >= 0 else { return nil }
        return CGRect(
            x: (CGFloat(minX) - rect.minX * scale) / scale,
            y: (CGFloat(minY) - rect.minY * scale) / scale,
            width: CGFloat(maxX - minX + 1) / scale,
            height: CGFloat(maxY - minY + 1) / scale
        )
    }

    @MainActor
    private func overlays(in textView: MarkdownTextView) -> [SpoilerOverlayView] {
        textView.subviews.compactMap { $0 as? SpoilerOverlayView }
    }

    @MainActor
    private func revealFirstSpoiler(in textView: MarkdownTextView) throws {
        textView.setMarkdownAttributedText(
            try XCTUnwrap(SpoilerInteraction.revealing(in: textView.attributedText, ordinals: [0]))
        )
        textView.layoutIfNeeded()
    }

    @MainActor
    private func renderSynchronously(_ store: MarkdownRenderStore, markdown: String, config: MarkdownStyleConfiguration) {
        let rendered = expectation(description: "render applied for \(markdown)")
        let cancellable = store.$source
            .dropFirst()
            .sink { _ in rendered.fulfill() }
        store.schedule(MarkdownRenderInputs(markdown: markdown, config: config))
        wait(for: [rendered], timeout: 2)
        cancellable.cancel()
    }

    private func assertConcealed(
        _ word: String,
        in text: NSAttributedString,
        stashing stashed: UIColor?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertEqual(try color(onWord: word, in: text), .clear, file: file, line: line)
        let stash = try attribute(MarkdownAttribute.spoilerOriginalColors, onWord: word, in: text)
        XCTAssertEqual((stash as? [NSAttributedString.Key: UIColor])?[.foregroundColor], stashed, file: file, line: line)
    }

    private func color(onWord word: String, in text: NSAttributedString) throws -> UIColor? {
        try attribute(.foregroundColor, onWord: word, in: text) as? UIColor
    }

    private func rangeOfWord(_ word: String, in text: NSAttributedString) throws -> NSRange {
        try XCTUnwrap(
            text.string.range(of: word).map { NSRange($0, in: text.string) },
            "'\(word)' not found in '\(text.string)'"
        )
    }

    private func attribute(_ key: NSAttributedString.Key, onWord word: String, in text: NSAttributedString) throws -> Any? {
        text.attribute(key, at: try rangeOfWord(word, in: text).location, effectiveRange: nil)
    }
}

/// A flat tint that reveals instantly, standing in for a consumer's effect.
private final class TintOverlayView: SpoilerOverlayView {
    override func animateReveal(completion: @escaping () -> Void) {
        completion()
    }
}

private struct TintOverlayProvider: SpoilerOverlayProvider {
    var fallback: UIColor?

    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        let view = TintOverlayView(charRange: charRange)
        view.backgroundColor = style.color ?? fallback
        return view
    }
}
