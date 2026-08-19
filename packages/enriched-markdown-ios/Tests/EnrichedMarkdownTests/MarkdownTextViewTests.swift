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
}
