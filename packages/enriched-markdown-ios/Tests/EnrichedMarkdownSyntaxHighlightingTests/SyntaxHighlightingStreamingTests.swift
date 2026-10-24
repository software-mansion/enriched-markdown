import UIKit
import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownStreaming
@testable import EnrichedMarkdownSyntaxHighlighting

final class SyntaxHighlightingStreamingTests: XCTestCase {
    private let open = "Intro\n\n```python\ndef f():\n    return 1\n"
    private let streaming = MarkdownStreamingOptions()

    private func makeSession(config: MarkdownStyleConfiguration, codeBlockLayout: MarkdownCodeBlockLayout) -> StreamingRenderSession {
        StreamingRenderSession(inputs: MarkdownRenderInputs(
            markdown: "",
            config: config,
            plugins: RenderPluginList(values: [SyntaxHighlightingPlugin()]),
            codeBlockLayout: codeBlockLayout
        ))
    }

    func testWrappingBlockIsColoredOnlyOnceItsFenceCloses() {
        let config = highlightingConfig()
        let session = makeSession(config: config, codeBlockLayout: .wrapping)

        let pending = session.render(open, options: streaming)
        XCTAssertEqual(pending.text.foregroundColor(of: "def"), config.codeBlock.foregroundColor ?? .label)

        let closed = session.render(open + "```", options: streaming)
        XCTAssertEqual(closed.text.foregroundColor(of: "def"), config.syntaxHighlight.colors[.keyword])
    }

    func testScrollablePanelIsColoredOnlyOnceItsFenceCloses() throws {
        let config = highlightingConfig()
        let session = makeSession(config: config, codeBlockLayout: .scrollable)
        let keyword = config.syntaxHighlight.colors[.keyword]

        let pending = try XCTUnwrap(attachments(of: CodeBlockAttachment.self, in: session.render(open, options: streaming).text).first)
        XCTAssertTrue(pending.isPending)
        XCTAssertNotEqual(pending.attributedCode.foregroundColor(of: "def"), keyword)

        let closed = try XCTUnwrap(attachments(of: CodeBlockAttachment.self, in: session.render(open + "```", options: streaming).text).first)
        XCTAssertFalse(closed.isPending)
        XCTAssertEqual(closed.attributedCode.foregroundColor(of: "def"), keyword)
    }

    func testClosedBlockMatchesAHighlightedRender() {
        let config = highlightingConfig()
        let session = makeSession(config: config, codeBlockLayout: .scrollable)
        _ = session.render(open, options: streaming)
        let closed = session.render(open + "```\n\nAfter", options: streaming)
        let full = MarkdownRenderer.renderSyntaxHighlighted(closed.source, config: config, codeBlockLayout: .scrollable)
        XCTAssertTrue(AttributedTextDiff.isEquivalent(closed.text, full))
    }
}
