import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

/// Hosts `EnrichedMarkdownText` the way apps embed it (scroll view, flexible
/// frame, padding) and checks that the text view's final frame matches its
/// settled content height — the segment pipeline and the representable's
/// measurement must not add or drop vertical space.
@MainActor
final class EnrichedMarkdownTextLayoutTests: XCTestCase {
    func testHostedTextViewFrameMatchesSettledContentHeight() {
        let markdown = "# Groceries\n\n- [x] milk with **bold** text\n- [ ] eggs\n- plain\n\n1. one\n2. two"
        let root = ScrollView {
            EnrichedMarkdownText(markdown)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }

        let host = UIHostingController(rootView: root)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 380, height: 1200))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        var textView: MarkdownTextView?
        for _ in 0..<60 {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            host.view.layoutIfNeeded()
            textView = findTextView(in: host.view)
            if let textView, textView.attributedText?.length ?? 0 > 0 {
                break
            }
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        host.view.layoutIfNeeded()
        window.isHidden = true

        guard let textView else { return XCTFail("markdown text view never appeared") }
        textView.layoutIfNeeded()
        let settled = textView.sizeThatFits(
            CGSize(width: textView.frame.width, height: .greatestFiniteMagnitude)
        ).height

        XCTAssertGreaterThan(settled, 50)
        XCTAssertEqual(textView.frame.height, settled, accuracy: 1.0)
    }

    private func findTextView(in view: UIView) -> MarkdownTextView? {
        if let textView = view as? MarkdownTextView { return textView }
        for subview in view.subviews {
            if let found = findTextView(in: subview) { return found }
        }
        return nil
    }
}
