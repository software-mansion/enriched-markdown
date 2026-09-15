import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class LinkInteractionTests: XCTestCase {
    private var coordinator: MarkdownTextViewRepresentable.Coordinator!
    private var textView: HandleTouchTextView!
    private let url = URL(string: "https://swmansion.com")!
    private let range = NSRange(location: 0, length: 4)

    override func setUp() {
        super.setUp()
        coordinator = MarkdownTextViewRepresentable.Coordinator()
        textView = HandleTouchTextView()
    }

    private func interact(_ interaction: UITextItemInteraction) -> Bool {
        coordinator.textView(textView, shouldInteractWith: url, in: range, interaction: interaction)
    }

    func testTapFiresPressHandlerAndConsumesInteraction() {
        var pressedURL: URL?
        coordinator.onLinkPress = { pressedURL = $0 }

        XCTAssertFalse(interact(.invokeDefaultAction))
        XCTAssertEqual(pressedURL, url)
    }

    func testTapWithoutHandlersKeepsSystemBehavior() {
        XCTAssertTrue(interact(.invokeDefaultAction))
    }

    func testLongPressPrefersLongPressHandler() {
        var pressed = false
        var longPressedURL: URL?
        coordinator.onLinkPress = { _ in pressed = true }
        coordinator.onLinkLongPress = { longPressedURL = $0 }

        XCTAssertFalse(interact(.presentActions))
        XCTAssertEqual(longPressedURL, url)
        XCTAssertFalse(pressed)
    }

    func testLongPressFallsBackToPressHandler() {
        // Pre-existing behavior: with only a press handler, every link
        // interaction fires it and suppresses the system menu.
        var pressedURL: URL?
        coordinator.onLinkPress = { pressedURL = $0 }

        XCTAssertFalse(interact(.presentActions))
        XCTAssertEqual(pressedURL, url)
    }

    func testLongPressWithoutHandlersKeepsSystemBehavior() {
        XCTAssertTrue(interact(.presentActions))
    }

    func testPreviewRoutesLikeLongPress() {
        var longPressedURL: URL?
        coordinator.onLinkLongPress = { longPressedURL = $0 }

        XCTAssertFalse(interact(.preview))
        XCTAssertEqual(longPressedURL, url)
    }

    func testHandleLinkLongPressReportsConsumption() {
        XCTAssertFalse(coordinator.handleLinkLongPress(url))

        coordinator.onLinkLongPress = { _ in }
        XCTAssertTrue(coordinator.handleLinkLongPress(url))
    }

    func testEnvironmentDefaultsToNoLongPressHandler() {
        XCTAssertNil(EnvironmentValues().markdownLinkLongPressHandler)
    }

    // MARK: - Selection handle grabs

    // Selecting the last word of a line parks the end knob on top of the
    // following line, where a press on it used to fire the link underneath.

    func testLongPressOnSelectionHandleFiresNothing() {
        var fired = false
        coordinator.onLinkPress = { _ in fired = true }
        coordinator.onLinkLongPress = { _ in fired = true }
        textView.isTouchOnSelectionHandle = true

        XCTAssertFalse(interact(.presentActions))
        XCTAssertFalse(fired)
    }

    func testTapOnSelectionHandleFiresNothing() {
        var fired = false
        coordinator.onLinkPress = { _ in fired = true }
        textView.isTouchOnSelectionHandle = true

        XCTAssertFalse(interact(.invokeDefaultAction))
        XCTAssertFalse(fired)
    }
}

// MARK: -

/// Stands in for `MarkdownTextView`, which is `final` and would need a window,
/// first responder status and a live selection to report a real grab.
private final class HandleTouchTextView: UITextView, SelectionHandleTouchReporting {
    var isTouchOnSelectionHandle = false
}
