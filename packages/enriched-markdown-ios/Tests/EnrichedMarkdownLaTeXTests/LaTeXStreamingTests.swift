import UIKit
import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownStreaming
@testable import EnrichedMarkdownLaTeX

final class LaTeXStreamingTests: XCTestCase {
    private let markdown = """
    Die Fläche eines Kreises ist $A = \\pi r^2$, sein Umfang $U = 2\\pi r$.

    $$
    \\int_0^1 x^2 \\, dx = \\frac{1}{3}
    $$

    Ein Heft kostet 3$ und ein Stift 2 $ pro Stück.

    Für $x_1 = 2$ gilt $$x_1^2 = 4$$ — fertig.
    """

    private let streaming = MarkdownStreamingOptions()

    private func makeSession(config: MarkdownStyleConfiguration) -> StreamingRenderSession {
        StreamingRenderSession(inputs: MarkdownRenderInputs(
            markdown: "",
            config: config,
            plugins: RenderPluginList(values: [LaTeXRenderPlugin()])
        ))
    }

    func testStreamedMathEndsIdenticalToANonStreamedRender() {
        let config = MarkdownStyleConfiguration.baseline()
        let session = makeSession(config: config)
        var index = markdown.startIndex
        while index < markdown.endIndex {
            index = markdown.index(index, offsetBy: 4, limitedBy: markdown.endIndex) ?? markdown.endIndex
            let streamed = session.render(String(markdown[..<index]), options: streaming)
            let full = MarkdownRenderer.render(
                streamed.source,
                config: config,
                options: .commonMark,
                imageRequestHeaders: [:],
                plugins: [LaTeXRenderPlugin()]
            )
            XCTAssertTrue(AttributedTextDiff.isEquivalent(streamed.text, full), "prefix \(streamed.source.debugDescription)")
        }
    }

    func testUnclosedMathStaysHidden() {
        let session = makeSession(config: .baseline())
        let inline = session.render("Die Fläche ist $A = \\pi r^", options: streaming)
        XCTAssertEqual(inline.text.string.trimmingCharacters(in: .whitespacesAndNewlines), "Die Fläche ist")
        let block = session.render("Die Fläche ist\n\n$$\n\\int_0^1 x", options: streaming)
        XCTAssertFalse(block.text.string.contains("$"))
        XCTAssertFalse(block.text.string.contains("int"))
    }

    func testPricesStayText() {
        let session = makeSession(config: .baseline())
        let result = session.render("Ein Heft kostet 3$ und ein Stift 2 $ pro", options: streaming)
        XCTAssertTrue(result.text.string.contains("3$ und ein Stift 2 $ pro"))
    }

    @MainActor
    func testStableMathBlockKeepsItsView() throws {
        let (window, textView) = hostedTextView()
        defer { window.isHidden = true }
        let session = makeSession(config: .baseline())
        let block = "$$\nx^2 + y^2 = z^2\n$$\n\n"

        let before = try blockView(showing: session.render(block + "Next", options: streaming), in: textView)
        let after = try blockView(showing: session.render(block + "Next paragraph grows", options: streaming), in: textView)

        XCTAssertTrue(after === before)
    }

    @MainActor
    func testOpenMathBlockKeepsItsView() throws {
        let (window, textView) = hostedTextView()
        defer { window.isHidden = true }
        let session = makeSession(config: .baseline())
        let block = "$$\nx^2 + y^2 = z^2\n$$\n\n"
        let first = session.render(block + "- item", options: streaming)
        let second = session.render(block + "- item grows", options: streaming)

        let before = try blockView(showing: first, in: textView)
        let after = try blockView(showing: second, in: textView)

        XCTAssertFalse(mathAttachments(in: first.text).first === mathAttachments(in: second.text).first, "the open tail re-renders the block")
        XCTAssertTrue(after === before)
    }

    @MainActor
    private func blockView(showing result: StreamingRenderResult, in textView: MarkdownTextView) throws -> MathBlockView {
        textView.setMarkdownAttributedText(result.text, lineage: result.lineage)
        settle(textView)
        return try XCTUnwrap(textView.firstSubview(of: MathBlockView.self))
    }
}
