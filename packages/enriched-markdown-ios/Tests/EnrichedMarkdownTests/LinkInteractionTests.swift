import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class LinkInteractionTests: XCTestCase {
    private var coordinator: MarkdownTextViewRepresentable.Coordinator!
    private var textView: UITextView!
    private let url = URL(string: "https://swmansion.com")!
    private let range = NSRange(location: 0, length: 4)

    override func setUp() {
        super.setUp()
        coordinator = MarkdownTextViewRepresentable.Coordinator()
        textView = UITextView()
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
}
