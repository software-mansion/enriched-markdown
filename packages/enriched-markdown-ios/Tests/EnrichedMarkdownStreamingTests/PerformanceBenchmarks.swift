import UIKit
import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownStreaming

final class PerformanceBenchmarks: XCTestCase {
    private static let config = MarkdownStyleConfiguration.baseline()

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["ENRICHED_MARKDOWN_BENCHMARKS"] != nil,
            "set ENRICHED_MARKDOWN_BENCHMARKS to run the benchmarks"
        )
    }

    private static let streamedAnswer = (1...8)
        .map { StreamingFixtures.answer.replacingOccurrences(of: "# Photosynthese", with: "# \($0). Photosynthese") }
        .joined(separator: "\n\n")

    func testStreamingUpdatesOfLongAnswer() {
        let updates = StreamingFixtures.chunks(of: Self.streamedAnswer, sizes: [6, 14, 9, 21, 11, 4, 17])
        measure {
            let session = StreamingRenderSession(inputs: MarkdownRenderInputs(markdown: "", config: Self.config))
            let textView = MarkdownTextView()
            textView.styleConfig = Self.config
            textView.frame = CGRect(x: 0, y: 0, width: 390, height: 100)
            for prefix in updates {
                let result = session.render(prefix, options: MarkdownStreamingOptions())
                textView.setMarkdownAttributedText(result.text, lineage: result.lineage)
                _ = textView.sizeThatFits(CGSize(width: 390, height: CGFloat.greatestFiniteMagnitude))
            }
        }
    }
}
