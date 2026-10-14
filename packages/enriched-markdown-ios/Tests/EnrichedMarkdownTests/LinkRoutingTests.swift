import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

/// With no `onLinkPress` handler, every link path goes through the
/// environment's `openURL`: text taps (covered by LinkInteractionTests),
/// table-cell taps, and VoiceOver activation.
@MainActor
final class LinkRoutingTests: XCTestCase {
    private var window: UIWindow?
    private let url = URL(string: "https://swmansion.com")!

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testVoiceOverActivationOpensThroughOpenURL() throws {
        var opened: URL?
        let textView = try hostedTextView("[press me](https://swmansion.com)") { opened = $0 }

        let link = try XCTUnwrap(textView.accessibilityElements?.first as? MarkdownAccessibilityElement)
        XCTAssertTrue(link.accessibilityActivate())
        XCTAssertEqual(opened, url)
    }

    func testTableCellLinkOpensThroughOpenURL() throws {
        var opened: URL?
        let textView = try hostedTextView("| A |\n|---|\n| [cell](https://swmansion.com) |") { opened = $0 }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        textView.layoutIfNeeded()

        let table = try XCTUnwrap(textView.firstSubview(of: TableAttachmentView.self))
        table.openLink(url)
        XCTAssertEqual(opened, url)
    }

    private func hostedTextView(_ markdown: String, openURL: @escaping (URL) -> Void) throws -> MarkdownTextView {
        let representable = MarkdownTextViewRepresentable.fixture(
            attributedText: MarkdownRenderer.render(markdown, config: .baseline()),
            openURL: openURL
        )
        let (window, textView) = try host(representable, size: CGSize(width: 380, height: 800))
        self.window = window
        return textView
    }
}
