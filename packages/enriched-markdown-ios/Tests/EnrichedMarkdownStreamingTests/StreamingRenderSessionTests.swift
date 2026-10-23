import Combine
import UIKit
import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownStreaming

final class StreamingRenderSessionTests: XCTestCase {
    private let config = MarkdownStyleConfiguration.baseline()
    private let streaming = MarkdownStreamingOptions()
    private let openFence = "Intro\n\n```swift\nlet x = 1\n"

    private func fullRender(
        _ markdown: String,
        options: MarkdownParsingOptions = .commonMark,
        codeBlockLayout: MarkdownCodeBlockLayout = .wrapping
    ) -> NSAttributedString {
        MarkdownRenderer.render(markdown, config: config, options: options, codeBlockLayout: codeBlockLayout)
    }

    private func assertEquivalent(
        _ lhs: NSAttributedString,
        _ rhs: NSAttributedString,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard !AttributedTextDiff.isEquivalent(lhs, rhs) else { return }
        let diff = AttributedTextDiff(from: lhs, to: rhs)
        XCTFail(
            "\(message): differs at \(diff.replacedRange) — \(lhs.string.debugDescription) vs \(rhs.string.debugDescription)",
            file: file,
            line: line
        )
    }

    private func assertEveryPrefixRendersWhole(
        _ markdown: String,
        options: MarkdownParsingOptions = .commonMark,
        codeBlockLayout: MarkdownCodeBlockLayout = .wrapping,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let session = StreamingFixtures.session(options: options, codeBlockLayout: codeBlockLayout)
        for prefix in StreamingFixtures.chunks(of: markdown) {
            let result = session.render(prefix, options: MarkdownStreamingOptions(codeBlocks: .hidden))
            assertEquivalent(
                result.text,
                fullRender(result.source, options: options, codeBlockLayout: codeBlockLayout),
                "prefix of \(prefix.count) characters",
                file: file,
                line: line
            )
        }
    }

    func testEveryPrefixRendersAsTheWholeDocumentWould() {
        assertEveryPrefixRendersWhole(StreamingFixtures.answer)
    }

    func testEveryPrefixRendersAsTheWholeDocumentWouldWithScrollableCodeBlocks() {
        assertEveryPrefixRendersWhole(StreamingFixtures.answer, codeBlockLayout: .scrollable)
    }

    func testEveryPrefixRendersAsTheWholeDocumentWouldWithExtendedSyntax() {
        assertEveryPrefixRendersWhole(StreamingFixtures.extendedAnswer, options: StreamingFixtures.extendedOptions)
    }

    func testStreamEndsIdenticalToANonStreamedRender() throws {
        let session = StreamingFixtures.session()
        let markdown = StreamingFixtures.answer
        var final: StreamingRenderResult?
        for prefix in StreamingFixtures.chunks(of: markdown) {
            final = session.render(prefix, options: streaming)
        }
        XCTAssertEqual(final?.source, markdown)
        assertEquivalent(try XCTUnwrap(final).text, fullRender(markdown), "final render")
    }

    func testFinishedBlocksAreKeptAcrossUpdates() {
        let session = StreamingFixtures.session()
        var previous: StreamingRenderResult?
        var sawStableBlocks = false
        for prefix in StreamingFixtures.chunks(of: StreamingFixtures.answer) {
            let result = session.render(prefix, options: streaming)
            if let previous {
                XCTAssertEqual(result.lineage.session, previous.lineage.session, "one session for an extending stream")
                XCTAssertGreaterThanOrEqual(result.lineage.stableLength, previous.lineage.stableLength)
                let stable = NSRange(location: 0, length: previous.lineage.stableLength)
                XCTAssertTrue(
                    result.text.attributedSubstring(from: stable).isEqual(previous.text.attributedSubstring(from: stable)),
                    "finished blocks never change"
                )
            }
            sawStableBlocks = sawStableBlocks || result.lineage.stableLength > 0
            previous = result
        }
        XCTAssertTrue(sawStableBlocks)
    }

    func testUnfinishedSyntaxNeverShowsRaw() {
        let result = StreamingFixtures.session().render("Intro\n\nThis is **bold and `co", options: streaming)
        XCTAssertEqual(result.text.string.trimmingCharacters(in: .newlines), "Intro\nThis is bold and co")
    }

    func testNoPrefixShowsRawSyntax() {
        let session = StreamingFixtures.session()
        for prefix in StreamingFixtures.chunks(of: StreamingFixtures.answer, sizes: [1]) {
            let text = session.render(prefix, options: streaming).text.string
            for syntax in ["**", "`", "~~", "[", "]", "|", "\n-\n", "\n=\n"] {
                XCTAssertFalse(text.contains(syntax), "\(syntax.debugDescription) shows raw after \(prefix.suffix(30).debugDescription)")
            }
        }
    }

    func testHiddenTableAppearsWhenComplete() {
        let session = StreamingFixtures.session()
        let options = MarkdownStreamingOptions(tables: .hidden)
        let table = "| A | B |\n|---|---|\n| 1 | 2 |"
        XCTAssertTrue(attachments(of: TableAttachment.self, in: session.render("Intro\n\n" + table, options: options).text).isEmpty)
        XCTAssertFalse(attachments(of: TableAttachment.self, in: session.render("Intro\n\n" + table + "\n\nAfter", options: options).text).isEmpty)
    }

    func testTrailingBlockMarginSurvivesAWithheldTail() {
        let session = StreamingFixtures.session()
        let markdown = "Para\n\n___\n\n| A | B |\n|---|---|\n| 1 | 2 |"
        _ = session.render("Para\n\n___\n\n| A | B |", options: streaming)
        _ = session.render("Para\n\n___\n\n| A | B |\n|--", options: streaming)
        assertEquivalent(session.render(markdown, options: streaming).text, fullRender(markdown), "thematic break before a withheld table")
    }

    func testMarkdownThatDoesNotExtendStartsANewLineage() {
        let session = StreamingFixtures.session()
        let first = session.render("First answer.\n\nSecond paragraph", options: streaming)
        let second = session.render("A different answer", options: streaming)
        XCTAssertNotEqual(first.lineage.session, second.lineage.session)
        assertEquivalent(second.text, fullRender("A different answer"), "after a restart")
    }

    func testLinkReferenceDefinitionsRenderWhole() throws {
        let session = StreamingFixtures.session()
        let markdown = "See [the docs][docs].\n\nMore text.\n\n[docs]: https://example.com"
        var final: StreamingRenderResult?
        for prefix in StreamingFixtures.chunks(of: markdown) {
            final = session.render(prefix, options: streaming)
        }
        assertEquivalent(try XCTUnwrap(final).text, fullRender(markdown), "reference links")
    }

    func testSourceRangesIndexTheWholeDocument() {
        let session = StreamingFixtures.session()
        let markdown = "First paragraph.\n\nSecond **bold** one."
        _ = session.render("First paragraph.\n\nSec", options: streaming)
        let result = session.render(markdown, options: streaming)
        XCTAssertGreaterThan(result.lineage.stableLength, 0)
        let boldLocation = (result.text.string as NSString).range(of: "bold").location
        let value = result.text.attribute(MarkdownAttribute.sourceRange, at: boldLocation, effectiveRange: nil) as? NSValue
        XCTAssertEqual(value?.rangeValue.location, (markdown as NSString).range(of: "bold").location)
    }

    func testOpenWrappingCodeBlockIsMarkedPendingUntilItsFenceCloses() {
        let session = StreamingFixtures.session()
        let open = session.render(openFence, options: streaming)
        XCTAssertTrue(open.text.string.contains("let x = 1"))
        XCTAssertTrue(hasAttribute(MarkdownAttribute.codeBlockPending, in: open.text))

        let closed = session.render(openFence + "```", options: streaming)
        XCTAssertFalse(hasAttribute(MarkdownAttribute.codeBlockPending, in: closed.text))
        assertEquivalent(closed.text, fullRender(openFence + "```"), "closed block")
    }

    func testOpenScrollableCodeBlockIsAPendingAttachment() {
        let session = StreamingFixtures.session(codeBlockLayout: .scrollable)
        let open = session.render(openFence, options: streaming)
        XCTAssertEqual(attachments(of: CodeBlockAttachment.self, in: open.text).map(\.isPending), [true])
        let closed = session.render(openFence + "```", options: streaming)
        XCTAssertEqual(attachments(of: CodeBlockAttachment.self, in: closed.text).map(\.isPending), [false])
    }

    func testOnlyTheOpenBlockIsPending() {
        let session = StreamingFixtures.session(codeBlockLayout: .scrollable)
        let result = session.render("```\nfirst\n```\n\n```\nsecond", options: streaming)
        XCTAssertEqual(attachments(of: CodeBlockAttachment.self, in: result.text).map(\.isPending), [false, true])
    }

    func testOpenBlockInsideAListItemIsPending() {
        let session = StreamingFixtures.session(codeBlockLayout: .scrollable)
        let result = session.render("- item\n\n  ```swift\n  let x = 1", options: streaming)
        XCTAssertEqual(attachments(of: CodeBlockAttachment.self, in: result.text).map(\.isPending), [true])
    }

    func testHiddenCodeBlockIsWithheldUntilItsFenceCloses() {
        let session = StreamingFixtures.session()
        let options = MarkdownStreamingOptions(codeBlocks: .hidden)
        XCTAssertFalse(session.render(openFence, options: options).text.string.contains("let x = 1"))
        let closed = session.render(openFence + "```", options: options)
        XCTAssertTrue(closed.text.string.contains("let x = 1"))
        XCTAssertFalse(hasAttribute(MarkdownAttribute.codeBlockPending, in: closed.text))
    }

    func testPendingBlockHasNoCopyAction() {
        let text = StreamingFixtures.session().render(openFence, options: streaming).text
        XCTAssertEqual(MarkdownAccessibilityElementBuilder.specs(for: text).last?.kind, .codeBlock(copyAction: nil, language: "swift"))
    }

    private func hasAttribute(_ key: NSAttributedString.Key, in text: NSAttributedString) -> Bool {
        var found = false
        text.enumerateAttribute(key, in: NSRange(location: 0, length: text.length)) { value, _, stop in
            if value != nil {
                found = true
                stop.pointee = true
            }
        }
        return found
    }
}

@MainActor
final class StreamingRenderStoreTests: XCTestCase {
    private let config = MarkdownStyleConfiguration.baseline()

    func testStreamPublishesLineageAndEndsAsAPlainRender() {
        let store = MarkdownRenderStore()
        let markdown = StreamingFixtures.answer
        store.schedule(MarkdownRenderInputs(markdown: String(markdown.prefix(600)), config: config, streaming: MarkdownStreamingOptions().plugin))
        awaitPublished(store.$lineage) { $0 != nil }
        let streamingSession = store.lineage?.session

        store.schedule(MarkdownRenderInputs(markdown: markdown, config: config))
        awaitPublished(store.$source) { $0?.markdown == markdown }

        XCTAssertTrue(AttributedTextDiff.isEquivalent(store.attributedText, MarkdownRenderer.render(markdown, config: config)))
        XCTAssertEqual(store.lineage, streamingSession.map { StreamingLineage(session: $0, stableLength: 0) })
    }

    func testChangedInputsEndAStreamWithAPlainRender() {
        let store = MarkdownRenderStore()
        let markdown = "Streamed **answer**"
        store.schedule(MarkdownRenderInputs(markdown: "Streamed **ans", config: config, streaming: MarkdownStreamingOptions().plugin))
        awaitPublished(store.$lineage) { $0 != nil }

        store.schedule(MarkdownRenderInputs(markdown: markdown, config: config, codeBlockLayout: .scrollable))
        awaitPublished(store.$source) { $0?.markdown == markdown }

        XCTAssertNil(store.lineage)
        XCTAssertTrue(AttributedTextDiff.isEquivalent(
            store.attributedText,
            MarkdownRenderer.render(markdown, config: config, codeBlockLayout: .scrollable)
        ))
    }

    func testStreamedSourceIsTheRenderedMarkdown() {
        let store = MarkdownRenderStore()
        store.schedule(MarkdownRenderInputs(markdown: "Intro\n\n| A | B |", config: config, streaming: MarkdownStreamingOptions().plugin))
        awaitPublished(store.$lineage) { $0 != nil }
        XCTAssertEqual(store.source?.markdown, "Intro\n\n")
    }

    func testTokensThatChangeNothingVisibleAreNotRepublished() {
        let store = MarkdownRenderStore()
        let options = MarkdownStreamingOptions(tables: .hidden)
        store.schedule(MarkdownRenderInputs(markdown: "Intro\n\n| A | B |", config: config, streaming: options.plugin))
        awaitPublished(store.$source) { $0?.markdown == "Intro\n\n" }

        var publishes = 0
        let cancellable = store.$attributedText.dropFirst().sink { _ in publishes += 1 }
        store.schedule(MarkdownRenderInputs(markdown: "Intro\n\n| A | B |\n|---|", config: config, streaming: options.plugin))
        drainMainQueue(for: 0.5)
        cancellable.cancel()

        XCTAssertEqual(publishes, 0)
        XCTAssertEqual(store.source?.markdown, "Intro\n\n")
    }
}
