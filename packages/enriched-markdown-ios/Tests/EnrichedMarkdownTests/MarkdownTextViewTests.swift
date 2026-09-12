import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class MarkdownTextViewTests: XCTestCase {
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
}
