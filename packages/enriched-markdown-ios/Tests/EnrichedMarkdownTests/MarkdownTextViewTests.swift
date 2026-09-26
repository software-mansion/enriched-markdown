import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class MarkdownTextViewTests: XCTestCase {
    /// A text view only keeps first responder status while its window is alive.
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testDefaultConfiguration() {
        let textView = MarkdownTextView()

        XCTAssertTrue(textView.isSelectionEnabled)
        XCTAssertTrue(textView.isSelectable)
        XCTAssertFalse(textView.isEditable)
        XCTAssertTrue(textView.canBecomeFirstResponder)
    }

    func testDisablingSelectionBlocksFirstResponder() {
        let textView = MarkdownTextView()

        textView.isSelectionEnabled = false

        XCTAssertFalse(textView.canBecomeFirstResponder)
    }

    func testDisablingSelectionClearsExistingSelection() {
        let textView = MarkdownTextView()
        textView.setMarkdownAttributedText(NSAttributedString(string: "Hello world"))
        textView.selectedRange = NSRange(location: 0, length: 5)
        XCTAssertEqual(textView.selectedRange.length, 5)

        textView.isSelectionEnabled = false

        XCTAssertEqual(textView.selectedRange.length, 0)
    }

    func testReenablingSelectionRestoresFirstResponder() {
        let textView = MarkdownTextView()

        textView.isSelectionEnabled = false
        textView.isSelectionEnabled = true

        XCTAssertTrue(textView.canBecomeFirstResponder)
    }

    func testSelectionStaysSelectableWhenDisabled() {
        // isSelectable must stay true while selection is gated: link taps
        // route through UITextViewDelegate only for selectable text views.
        let textView = MarkdownTextView()

        textView.isSelectionEnabled = false

        XCTAssertTrue(textView.isSelectable)
    }

    func testEnvironmentDefaults() {
        let environment = EnvironmentValues()

        XCTAssertTrue(environment.markdownSelectable)
        XCTAssertNil(environment.markdownSelectionColor)
    }

    // MARK: - Measurement cache

    // Measuring lays out the whole document, so the result is cached against
    // the width and the text it was measured for. These cover the
    // invalidation: a stale height is a misdrawn page, not a slow one.

    private func attributed(_ string: String, size: CGFloat = 17) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.font: UIFont.systemFont(ofSize: size)])
    }

    private static let measureWidth: CGFloat = 200

    private func height(of textView: MarkdownTextView, width: CGFloat = measureWidth) -> CGFloat {
        textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }

    func testRepeatedMeasurementsAgree() {
        let textView = MarkdownTextView()
        textView.setMarkdownAttributedText(attributed("One line of text"))

        XCTAssertEqual(height(of: textView), height(of: textView))
    }

    func testLongerTextMeasuresTaller() {
        let textView = MarkdownTextView()
        textView.setMarkdownAttributedText(attributed("Short"))
        let short = height(of: textView)

        textView.setMarkdownAttributedText(attributed(String(repeating: "Much longer body copy. ", count: 20)))

        XCTAssertGreaterThan(height(of: textView), short)
    }

    func testNarrowerWidthMeasuresTaller() {
        let textView = MarkdownTextView()
        textView.setMarkdownAttributedText(attributed(String(repeating: "Wrapping body copy. ", count: 10)))
        let wide = height(of: textView, width: 400)

        XCTAssertGreaterThan(height(of: textView, width: 120), wide)
    }

    /// Growing the font changes the height without changing the string, so the
    /// cache must key on the instance and not on its text.
    func testLargerFontMeasuresTallerForTheSameString() {
        let textView = MarkdownTextView()
        textView.setMarkdownAttributedText(attributed("Same string", size: 12))
        let small = height(of: textView)

        textView.setMarkdownAttributedText(attributed("Same string", size: 40))

        XCTAssertGreaterThan(height(of: textView), small)
    }

    /// A distinct instance holding equal content is not a re-render: the text
    /// view keeps what it has, and the measurement stays valid.
    func testEqualReplacementKeepsMeasurement() {
        let textView = MarkdownTextView()
        textView.setMarkdownAttributedText(attributed("Stable content"))
        let before = height(of: textView)

        textView.setMarkdownAttributedText(attributed("Stable content"))

        XCTAssertEqual(height(of: textView), before)
        XCTAssertEqual(textView.attributedText.string, "Stable content")
    }

    // MARK: - Selection handle hit testing

    /// On screen and selected is what it takes for UIKit to hand back caret
    /// rects; returns the text view and where its end knob sits.
    private func selectingTextView() throws -> (textView: MarkdownTextView, endKnob: CGPoint) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        self.window = window
        let textView = MarkdownTextView()
        textView.frame = window.bounds
        window.addSubview(textView)
        window.makeKeyAndVisible()
        textView.setMarkdownAttributedText(attributed("Selection handles sit at both ends"))
        textView.layoutIfNeeded()
        textView.becomeFirstResponder()
        textView.selectedRange = NSRange(location: 0, length: 9)

        let selection = try XCTUnwrap(textView.selectedTextRange)
        let end = textView.caretRect(for: selection.end)
        return (textView, CGPoint(x: end.midX, y: end.maxY))
    }

    func testPointOnEndKnobIsASelectionHandle() throws {
        let (textView, endKnob) = try selectingTextView()

        XCTAssertTrue(textView.isPointOnSelectionHandle(endKnob))
    }

    func testPointAwayFromKnobsIsNotASelectionHandle() throws {
        let (textView, endKnob) = try selectingTextView()

        XCTAssertFalse(textView.isPointOnSelectionHandle(endKnob.applying(.init(translationX: 120, y: 120))))
    }

    /// This is what keeps plain link taps working.
    func testNoSelectionMeansNoSelectionHandles() throws {
        let (textView, endKnob) = try selectingTextView()

        textView.selectedRange = NSRange(location: 0, length: 0)

        XCTAssertFalse(textView.isPointOnSelectionHandle(endKnob))
    }

    // MARK: - Image layout

    // A `maxHeight` image box is the cap until the image loads and only then
    // settles to the fitted height. The view has already been measured by
    // then, so it has to hear about it and measure again.

    private func imageDocument(
        _ image: BlockImage,
        downloader: ImageDownloading
    ) -> (text: NSAttributedString, attachment: MarkdownImageAttachment) {
        let attachment = MarkdownImageAttachment.attachment(
            for: "https://example.invalid/\(#function).png",
            config: imageSizingConfig(image),
            isInline: false,
            altText: "",
            downloader: downloader
        )
        let text = NSAttributedString(string: "\u{FFFC}", attributes: [.attachment: attachment])
        return (text, attachment)
    }

    func testSettingTextAdoptsImageAttachments() {
        let textView = MarkdownTextView()
        let document = imageDocument(BlockImage().maxHeight(150), downloader: DeferredImageDownloader())

        textView.setMarkdownAttributedText(document.text)

        XCTAssertTrue(document.attachment.layoutObserver === textView)
    }

    func testSettledImageBoxDropsTheCachedMeasurement() {
        let downloader = DeferredImageDownloader()
        let textView = MarkdownTextView()
        let document = imageDocument(BlockImage().maxHeight(150), downloader: downloader)
        textView.setMarkdownAttributedText(document.text)

        let before = height(of: textView, width: 300)

        downloader.complete(with: makeImage(width: 300, height: 100))
        drainMainQueue()

        // 300 points wide at 3:1 fits in 100, half a cap of 150.
        XCTAssertEqual(before - height(of: textView, width: 300), 50, accuracy: 1)
    }

    /// SwiftUI measured the view against the cap and must measure again.
    func testHostedViewShrinksOnceAMaxHeightImageSettles() throws {
        let downloader = DeferredImageDownloader()
        let document = imageDocument(BlockImage().maxHeight(150), downloader: downloader)
        let host = UIHostingController(rootView: hostedRepresentable(document.text))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        self.window = window
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        let textView = try XCTUnwrap(host.view.firstSubview(of: MarkdownTextView.self))
        let before = textView.frame.height

        downloader.complete(with: makeImage(width: 300, height: 100))
        awaitMainQueue()
        host.view.layoutIfNeeded()

        // 300 points wide at 3:1 fits in 100, half a cap of 150.
        XCTAssertEqual(before - textView.frame.height, 50, accuracy: 1)
    }

    func testFixedImageBoxKeepsItsMeasurementAcrossTheLoad() {
        let downloader = DeferredImageDownloader()
        let textView = MarkdownTextView()
        let document = imageDocument(BlockImage().height(200), downloader: downloader)
        textView.setMarkdownAttributedText(document.text)

        let before = height(of: textView, width: 300)

        downloader.complete(with: makeImage(width: 300, height: 100))
        drainMainQueue()

        XCTAssertEqual(height(of: textView, width: 300), before)
    }

    private func hostedRepresentable(_ text: NSAttributedString) -> some View {
        MarkdownTextViewRepresentable(
            attributedText: text,
            source: nil,
            styleConfig: .baseline(),
            openURL: { _ in },
            onLinkPress: nil,
            onLinkLongPress: nil,
            selectionMenuConfig: MarkdownSelectionMenu(),
            isSelectionEnabled: true,
            selectionColor: nil,
            onTaskListItemTap: nil,
            spoilerOverlay: ParticleSpoilerOverlayProvider(),
            onSpoilerTap: nil,
            accessibilityLabels: .default
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Decoration tiling

extension MarkdownTextViewTests {
    private func listTextView(items: Int) -> MarkdownTextView {
        let markdown = (1...items).map { "- Item \($0)" }.joined(separator: "\n")
        return laidOutTextView(showing: MarkdownRenderer.render(markdown, config: .baseline()))
    }

    /// A scroll view in a window, to host a text view as its ancestor.
    private func scrollViewInWindow() -> UIScrollView {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let scrollView = UIScrollView(frame: window.bounds)
        window.addSubview(scrollView)
        window.isHidden = false
        self.window = window
        return scrollView
    }

    private func decorationFrames(of textView: MarkdownTextView) -> [CGRect] {
        textView.subviews.compactMap { $0 as? MarkdownDecorationView }.map(\.frame)
    }

    func testDecorationsCoverTheDocumentOutsideAScrollView() {
        let textView = listTextView(items: 400)

        XCTAssertGreaterThan(textView.bounds.height, MarkdownTextView.decorationTileMargin * 3)
        XCTAssertEqual(decorationFrames(of: textView), [textView.bounds, textView.bounds])
    }

    func testDecorationsCoverAShortDocumentInsideAScrollView() {
        let textView = listTextView(items: 5)
        scrollViewInWindow().addSubview(textView)
        textView.layoutIfNeeded()

        XCTAssertEqual(decorationFrames(of: textView), [textView.bounds, textView.bounds])
    }

    func testDecorationsTileTheVisibleRegionOfTheScrollView() {
        let textView = listTextView(items: 400)
        let scrollView = scrollViewInWindow()
        scrollView.addSubview(textView)
        scrollView.contentSize = textView.bounds.size
        textView.layoutIfNeeded()

        let margin = MarkdownTextView.decorationTileMargin
        let initial = CGRect(x: 0, y: 0, width: 390, height: 844 + margin)
        XCTAssertEqual(decorationFrames(of: textView), [initial, initial])

        // Scrolling within the tile keeps it.
        scrollView.contentOffset = CGPoint(x: 0, y: margin / 2)
        XCTAssertEqual(decorationFrames(of: textView), [initial, initial])

        // Scrolling out of it moves the tile around the new visible region.
        let far: CGFloat = 4000
        scrollView.contentOffset = CGPoint(x: 0, y: far)
        let moved = CGRect(x: 0, y: far - margin, width: 390, height: 844 + margin * 2)
        XCTAssertEqual(decorationFrames(of: textView), [moved, moved])
        XCTAssertLessThan(moved.height, textView.bounds.height)

        // The tile never leaves the document.
        let end = textView.bounds.height - 844
        scrollView.contentOffset = CGPoint(x: 0, y: end)
        let last = decorationFrames(of: textView)[0]
        XCTAssertEqual(last.maxY, textView.bounds.height, accuracy: 0.001)
        XCTAssertTrue(last.contains(CGRect(x: 0, y: end, width: 390, height: 844)))
    }

    /// A tile that cuts through a code block still draws the block's
    /// rounded corners at the block's ends, not at the cut.
    func testTiledDrawMatchesFullDrawThroughACutCodeBlock() throws {
        let markdown = "Intro\n\n```\n" + (1...60).map { "line \($0)" }.joined(separator: "\n") + "\n```\n\nOutro"
        let textView = laidOutTextView(showing: MarkdownRenderer.render(markdown, config: .baseline()))
        let decorator = MarkdownViewportDecorator(
            backgroundView: MarkdownDecorationView(),
            foregroundView: MarkdownDecorationView()
        )
        decorator.updateStyleConfig(.baseline())
        let tile = CGRect(x: 0, y: 300, width: 390, height: 400)
        XCTAssertGreaterThan(textView.bounds.height, tile.maxY + 300)

        func rows(drawing rect: CGRect) throws -> [[UInt8]] {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: rect.size))
                decorator.draw(in: context.cgContext, textView: textView, tile: rect, pass: .background)
            }
            let cgImage = try XCTUnwrap(image.cgImage)
            let data = try XCTUnwrap(cgImage.dataProvider?.data) as Data
            return (0..<Int(rect.height)).map { row in
                Array(data[(row * cgImage.bytesPerRow)..<(row * cgImage.bytesPerRow + Int(rect.width) * 4)])
            }
        }

        let full = try rows(drawing: textView.bounds)
        let tiled = try rows(drawing: tile)
        for (row, pixels) in tiled.enumerated() {
            XCTAssertEqual(pixels, full[Int(tile.minY) + row], "row \(row) of the tile")
        }
    }
}
