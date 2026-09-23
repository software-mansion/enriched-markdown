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
        let config = MarkdownStyleConfiguration.baseline()
        let representable = MarkdownTextViewRepresentable(
            attributedText: MarkdownRenderer.render(markdown, config: config),
            source: nil,
            styleConfig: config,
            openURL: openURL,
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
        let host = UIHostingController(rootView: representable.fixedSize(horizontal: false, vertical: true))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 380, height: 800))
        self.window = window
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        return try XCTUnwrap(host.view.firstSubview(of: MarkdownTextView.self))
    }
}
