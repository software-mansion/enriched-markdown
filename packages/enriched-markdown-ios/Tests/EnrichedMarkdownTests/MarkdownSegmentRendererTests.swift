import Combine
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class MarkdownSegmentRendererTests: XCTestCase {
    private var config: MarkdownStyleConfig!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.baseline()
    }

    func testDocumentRendersAsSingleTextSegment() {
        let segments = MarkdownSegmentRenderer.renderSegments(
            "# Title\n\nSome **bold** text\n\n- [x] a task",
            config: config
        )

        XCTAssertEqual(segments.count, 1)
        guard case .text(let text) = segments[0].content else {
            return XCTFail("expected a text segment")
        }
        XCTAssertTrue(text.string.contains("Title"))
        XCTAssertTrue(text.string.contains("a task"))
    }

    /// Segmentation must not change rendering: the single segment's content
    /// is exactly what the direct renderer produces for the same input.
    func testTextSegmentMatchesDirectRender() {
        let markdown = "# Hello\n\n> quote\n\n- one\n- [ ] two"
        let segments = MarkdownSegmentRenderer.renderSegments(markdown, config: config)
        let direct = MarkdownRenderer.render(markdown, config: config)

        guard case .text(let text) = segments[0].content else {
            return XCTFail("expected a text segment")
        }
        XCTAssertTrue(text.isEqual(to: direct))
    }

    func testEmptyPlaceholderIsSingleEmptyTextSegment() {
        XCTAssertEqual(MarkdownSegmentRenderer.empty.count, 1)
        guard case .text(let text) = MarkdownSegmentRenderer.empty[0].content else {
            return XCTFail("expected a text segment")
        }
        XCTAssertEqual(text.length, 0)
    }
}

@MainActor
final class MarkdownRenderStoreTests: XCTestCase {
    func testInitialStateIsEmptyPlaceholder() {
        let store = MarkdownRenderStore()

        XCTAssertEqual(store.segments, MarkdownSegmentRenderer.empty)
        XCTAssertNil(store.sourceMarkdown)
    }

    func testBlankMarkdownResetsSynchronously() {
        let store = MarkdownRenderStore()

        store.schedule(markdown: "   ", config: .baseline())

        XCTAssertEqual(store.segments, MarkdownSegmentRenderer.empty)
        XCTAssertNil(store.sourceMarkdown)
    }

    func testScheduleAppliesRenderedSegmentsWithSource() {
        let store = MarkdownRenderStore()
        let applied = expectation(description: "segments applied")

        let cancellable = store.$segments.dropFirst().sink { segments in
            XCTAssertEqual(segments.count, 1)
            if case .text(let text) = segments[0].content {
                XCTAssertTrue(text.string.contains("Hello"))
            } else {
                XCTFail("expected a text segment")
            }
            applied.fulfill()
        }

        store.schedule(markdown: "# Hello", config: .baseline())

        wait(for: [applied], timeout: 2)
        cancellable.cancel()
        XCTAssertEqual(store.sourceMarkdown, "# Hello")
    }
}
