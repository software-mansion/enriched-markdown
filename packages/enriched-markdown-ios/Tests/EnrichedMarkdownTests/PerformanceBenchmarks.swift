import UIKit
import XCTest
@testable import EnrichedMarkdown

/// Opt-in benchmarks of the render and decoration paths, skipped unless the
/// test process has `ENRICHED_MARKDOWN_BENCHMARKS` set. From the package:
///
///     TEST_RUNNER_ENRICHED_MARKDOWN_BENCHMARKS=1 xcodebuild test \
///         -scheme EnrichedMarkdown-Package \
///         -destination 'platform=iOS Simulator,name=iPhone 17' \
///         -only-testing:EnrichedMarkdownTests/PerformanceBenchmarks 2>&1 | grep measured
///
/// Every test reports one document; compare the `measured` lines (`Time` or
/// `Clock Monotonic Time`, plus `Memory Peak Physical` for the display tests)
/// between two checkouts, or set baselines in Xcode's test report.
final class PerformanceBenchmarks: XCTestCase {
    private static let config = MarkdownStyleConfiguration.baseline()

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["ENRICHED_MARKDOWN_BENCHMARKS"] != nil,
            "set ENRICHED_MARKDOWN_BENCHMARKS to run the benchmarks"
        )
    }

    // MARK: - Documents

    private static let longList = (1...2000)
        .map { "- Item **\($0)** with *some* text and `code`" }
        .joined(separator: "\n")

    private static let boldParagraphs = (1...500)
        .map { paragraph in
            (1...8).map { "**bold \(paragraph).\($0)** and *em \($0)* and ~~s~~ plain" }.joined(separator: " ")
        }
        .joined(separator: "\n\n")

    private static let nestedQuotes = (1...300)
        .map { "> Quote \($0) with **bold**\n> second line\n>\n> > nested \($0)" }
        .joined(separator: "\n\n")

    private static let codeBlocks = (1...200)
        .map { "```swift\nlet x\($0) = \($0)\nprint(x\($0))\n```" }
        .joined(separator: "\n\n")

    /// A mix of everything the decoration views draw, long enough to scroll.
    private static let mixed = (1...60)
        .map { section in
            """
            ## Section \(section)

            Paragraph with **bold**, *italic*, `code` and a [link](https://example.com).

            - Item one
              - Nested **item**
            - [ ] Task
            - [x] Done

            > Quote \(section)
            > > Nested quote

            ```swift
            let value = \(section)
            ```
            """
        }
        .joined(separator: "\n\n")

    // MARK: - Rendering

    func testRenderLongList() {
        measure { _ = MarkdownRenderer.render(Self.longList, config: Self.config) }
    }

    func testRenderBoldParagraphs() {
        measure { _ = MarkdownRenderer.render(Self.boldParagraphs, config: Self.config) }
    }

    func testRenderNestedQuotes() {
        measure { _ = MarkdownRenderer.render(Self.nestedQuotes, config: Self.config) }
    }

    func testRenderMixedDocument() {
        measure { _ = MarkdownRenderer.render(Self.mixed, config: Self.config) }
    }

    // MARK: - Layout

    func testFirstLayoutOfLongList() {
        let rendered = MarkdownRenderer.render(Self.longList, config: Self.config)
        measure {
            let textView = MarkdownTextView()
            textView.styleConfig = Self.config
            textView.frame = CGRect(x: 0, y: 0, width: 390, height: 100)
            textView.setMarkdownAttributedText(rendered)
            _ = textView.sizeThatFits(CGSize(width: 390, height: CGFloat.greatestFiniteMagnitude))
        }
    }

    // MARK: - Decorations

    /// One repaint of both decoration views, as a layout pass or a SwiftUI
    /// update triggers it, for a text view shown inside a scroll view.
    func testDecorationDisplayOfMixedDocument() {
        measureDecorationDisplay(of: Self.mixed)
    }

    func testDecorationDisplayOfLongList() {
        measureDecorationDisplay(of: Self.longList)
    }

    func testDecorationDisplayOfCodeBlocks() {
        measureDecorationDisplay(of: Self.codeBlocks)
    }

    private func measureDecorationDisplay(of markdown: String) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let scrollView = UIScrollView(frame: window.bounds)
        window.addSubview(scrollView)
        window.isHidden = false
        defer { window.isHidden = true }

        let textView = MarkdownTextView()
        textView.styleConfig = Self.config
        textView.frame = CGRect(x: 0, y: 0, width: 390, height: 100)
        scrollView.addSubview(textView)
        textView.setMarkdownAttributedText(MarkdownRenderer.render(markdown, config: Self.config))
        let height = textView.sizeThatFits(CGSize(width: 390, height: CGFloat.greatestFiniteMagnitude)).height
        textView.frame = CGRect(x: 0, y: 0, width: 390, height: height)
        scrollView.contentSize = textView.frame.size
        scrollView.contentOffset = CGPoint(x: 0, y: height / 2)
        textView.layoutIfNeeded()

        let decorationViews = textView.subviews.filter { $0 is MarkdownDecorationView }
        XCTAssertEqual(decorationViews.count, 2)
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for view in decorationViews {
                view.setNeedsDisplay()
                view.layer.displayIfNeeded()
            }
        }
    }
}
