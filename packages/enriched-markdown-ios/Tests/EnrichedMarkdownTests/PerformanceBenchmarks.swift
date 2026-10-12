import UIKit
import XCTest
@testable import EnrichedMarkdown

/// Opt-in benchmarks of the render, accessibility and decoration paths and
/// of the memory a document takes, skipped unless the test process has
/// `ENRICHED_MARKDOWN_BENCHMARKS` set. From the package:
///
///     TEST_RUNNER_ENRICHED_MARKDOWN_BENCHMARKS=1 xcodebuild test \
///         -scheme EnrichedMarkdown-Package \
///         -destination 'platform=iOS Simulator,name=iPhone 17' \
///         -only-testing:EnrichedMarkdownTests/PerformanceBenchmarks 2>&1 | grep measured
///
/// Every test reports one document; compare the `measured` lines (`Time`,
/// `Heap Growth` or `Footprint Growth`) between two checkouts, or set
/// baselines in Xcode's test report.
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

    // MARK: - Accessibility

    /// The VoiceOver element descriptions, built on the first query after
    /// every text change.
    func testAccessibilitySpecsOfLongList() {
        let rendered = MarkdownRenderer.render(Self.longList, config: Self.config)
        measure { _ = MarkdownAccessibilityElementBuilder.specs(for: rendered) }
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
        displaying(MarkdownRenderer.render(markdown, config: Self.config)) { textView in
            let decorationViews = textView.subviews.filter { $0 is MarkdownDecorationView }
            XCTAssertEqual(decorationViews.count, 2)
            measure {
                for view in decorationViews {
                    view.setNeedsDisplay()
                    view.layer.displayIfNeeded()
                }
            }
        }
    }

    // MARK: - Memory

    func testMemoryOfRenderedLongList() {
        measureRenderedMemory(of: Self.longList)
    }

    func testMemoryOfRenderedMixedDocument() {
        measureRenderedMemory(of: Self.mixed)
    }

    func testMemoryOfDisplayedMixedDocument() {
        measureDisplayedMemory(of: Self.mixed)
    }

    func testMemoryOfDisplayedLongList() {
        measureDisplayedMemory(of: Self.longList)
    }

    func testMemoryOfDisplayedCodeBlocks() {
        measureDisplayedMemory(of: Self.codeBlocks)
    }

    func testMemoryOfAccessibilityTreeOfLongList() {
        let rendered = MarkdownRenderer.render(Self.longList, config: Self.config)
        measure(metrics: [MemoryGrowthMetric(.heap)], options: Self.manualMeasurement) {
            let textView = MarkdownTextView()
            textView.setMarkdownAttributedText(rendered)
            startMeasuring()
            autoreleasepool { _ = textView.accessibilityElements }
            withExtendedLifetime(textView) { stopMeasuring() }
        }
    }

    private static let manualMeasurement: XCTMeasureOptions = {
        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        return options
    }()

    private func measureRenderedMemory(of markdown: String) {
        measure(metrics: [MemoryGrowthMetric(.heap)], options: Self.manualMeasurement) {
            startMeasuring()
            let rendered = autoreleasepool { MarkdownRenderer.render(markdown, config: Self.config) }
            withExtendedLifetime(rendered) { stopMeasuring() }
        }
    }

    private func measureDisplayedMemory(of markdown: String) {
        let rendered = MarkdownRenderer.render(markdown, config: Self.config)
        measure(metrics: [MemoryGrowthMetric(.heap), MemoryGrowthMetric(.footprint)], options: Self.manualMeasurement) {
            startMeasuring()
            displaying(rendered) { _ in
                autoreleasepool { CATransaction.flush() }
                stopMeasuring()
            }
        }
    }

    // MARK: - Showing a document

    /// UIKit autoreleases the views it creates and hides and frees their
    /// layers on a later main queue pass, hence the pools and the wait.
    private func displaying(_ rendered: NSAttributedString, _ body: (MarkdownTextView) -> Void) {
        weak var shown: MarkdownTextView?
        autoreleasepool {
            let (window, textView): (UIWindow, MarkdownTextView) = autoreleasepool {
                let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
                let scrollView = UIScrollView(frame: window.bounds)
                window.addSubview(scrollView)
                window.isHidden = false
                let textView = laidOutTextView(showing: rendered, config: Self.config)
                scrollView.addSubview(textView)
                scrollView.contentSize = textView.bounds.size
                scrollView.contentOffset = CGPoint(x: 0, y: textView.bounds.height / 2)
                return (window, textView)
            }
            shown = textView
            body(textView)
            window.isHidden = true
        }
        awaitMainQueue()
        XCTAssertNil(shown, "the shown text view outlived its window")
    }
}

/// The footprint keeps counting the pages malloc hands out again after a
/// free, so the heap is read from malloc itself.
private final class MemoryGrowthMetric: NSObject, XCTMetric {
    enum Measure: String {
        case heap = "Heap Growth"
        case footprint = "Footprint Growth"

        func bytes() -> Double {
            switch self {
            case .heap:
                var statistics = malloc_statistics_t()
                malloc_zone_statistics(nil, &statistics)
                return Double(statistics.size_in_use)
            case .footprint:
                var info = task_vm_info_data_t()
                var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
                let result = withUnsafeMutablePointer(to: &info) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
                    }
                }
                precondition(result == KERN_SUCCESS)
                return Double(info.phys_footprint)
            }
        }
    }

    private let measure: Measure
    private var startBytes: Double = 0
    private var growth: Double = 0

    init(_ measure: Measure) {
        self.measure = measure
    }

    func willBeginMeasuring() {
        startBytes = measure.bytes()
    }

    func didStopMeasuring() {
        growth = measure.bytes() - startBytes
    }

    func reportMeasurements(
        from startTime: XCTPerformanceMeasurementTimestamp,
        to endTime: XCTPerformanceMeasurementTimestamp
    ) throws -> [XCTPerformanceMeasurement] {
        [XCTPerformanceMeasurement(
            identifier: "com.swmansion.enriched.markdown.benchmarks.\(measure)",
            displayName: measure.rawValue,
            value: Measurement(value: growth / 1000, unit: UnitInformationStorage.kilobytes),
            polarity: .prefersSmaller
        )]
    }

    func copy(with zone: NSZone? = nil) -> Any {
        MemoryGrowthMetric(measure)
    }
}
