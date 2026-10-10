import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownSyntaxHighlighting

private final class HighlightingModel: ObservableObject {
    @Published var isEnabled: Bool = false
}

private struct HighlightingHarness: View {
    @ObservedObject var model: HighlightingModel
    let markdown: String

    var body: some View {
        EnrichedMarkdownText(markdown)
            .markdownSyntaxHighlighting(model.isEnabled)
    }
}

@MainActor
final class SyntaxHighlightingViewTests: XCTestCase {
    private var window: UIWindow?
    private let markdown = "```python\ndef f():\n    return 1\n```"

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func host<Content: View>(_ view: Content) -> UIView {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 380, height: 800))
        self.window = window
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        return host.view
    }

    private func color(of substring: String, in root: UIView) -> UIColor? {
        root.firstSubview(of: MarkdownTextView.self)?.attributedText?.foregroundColor(of: substring)
    }

    private func wait(timeout: TimeInterval = 5, until condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        return condition()
    }

    func testModifierHighlightsHostedText() {
        let root = host(EnrichedMarkdownText(markdown).markdownSyntaxHighlighting())
        let keyword = highlightingConfig(style: root.traitCollection.userInterfaceStyle).syntaxHighlight.colors[.keyword]

        XCTAssertTrue(wait { self.color(of: "def", in: root) != nil })
        XCTAssertEqual(color(of: "def", in: root), keyword)
    }

    func testInnermostModifierWins() {
        let root = host(
            VStack {
                EnrichedMarkdownText(markdown)
                    .markdownSyntaxHighlighting(false)
            }
            .markdownSyntaxHighlighting()
        )
        let codeColor = MarkdownStyleConfiguration.baseline(traitCollection: root.traitCollection).codeBlock.foregroundColor

        XCTAssertTrue(wait { self.color(of: "def", in: root) != nil })
        XCTAssertEqual(color(of: "def", in: root), codeColor)
    }

    func testTogglingTheModifierRerenders() {
        let model = HighlightingModel()
        let root = host(HighlightingHarness(model: model, markdown: markdown))
        XCTAssertTrue(wait { self.color(of: "def", in: root) != nil })
        let plain = color(of: "def", in: root)

        model.isEnabled = true
        XCTAssertTrue(wait { self.color(of: "def", in: root) != plain }, "enabling did not re-render")
        XCTAssertEqual(color(of: "return", in: root), color(of: "def", in: root))

        model.isEnabled = false
        XCTAssertTrue(wait { self.color(of: "def", in: root) == plain }, "disabling did not re-render")
    }
}
