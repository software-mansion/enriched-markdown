import UIKit
import XCTest
@testable import EnrichedMarkdown

private final class StubAttachment: NSTextAttachment, MarkdownPluginAttachment {
    let markdown: String
    let isBlock: Bool

    init(markdown: String, isBlock: Bool) {
        self.markdown = markdown
        self.isBlock = isBlock
        super.init(data: nil, ofType: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func markdownText() -> String { markdown }
}

/// Emits a stub attachment, taking block-ness from the context like a real
/// plugin renderer would.
private final class StubAttachmentRenderer: NodeRenderer {
    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        var attributes = context.getTextAttributes()
        attributes[.attachment] = StubAttachment(markdown: "$stub$", isBlock: context.rendersPluginBlock)
        output.append(NSAttributedString(string: "\u{FFFC}", attributes: attributes))
    }
}

private final class MarkerTextRenderer: NodeRenderer {
    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        output.append(NSAttributedString(string: "[plugin]", attributes: context.getTextAttributes()))
    }
}

/// Rides on the math md4c extension for a node type base has no renderer
/// for, like the LaTeX module does.
private struct StubPlugin: MarkdownRenderPlugin {
    let claimed: Set<NodeType>
    let makeRenderer: () -> NodeRenderer

    func renderer(for type: NodeType, config: MarkdownStyleConfig) -> NodeRenderer? {
        claimed.contains(type) ? makeRenderer() : nil
    }

    func adjustFlags(_ flags: inout Md4cFlags) {
        flags.latexMathEnabled = true
    }

    var rootBlockNodeTypes: Set<NodeType> { [.latexMathDisplay] }
}

final class RenderPluginTests: XCTestCase {
    private var config: MarkdownStyleConfig!

    private let mathStubPlugin = StubPlugin(
        claimed: [.latexMathInline, .latexMathDisplay],
        makeRenderer: { StubAttachmentRenderer() }
    )

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.baseline()
    }

    private func render(_ markdown: String, plugins: [any MarkdownRenderPlugin]) -> NSAttributedString {
        MarkdownRenderer.render(
            markdown,
            config: config,
            flags: .commonMark,
            imageRequestHeaders: [:],
            plugins: plugins
        )
    }

    private func stubAttachments(in rendered: NSAttributedString) -> [StubAttachment] {
        var found: [StubAttachment] = []
        rendered.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: rendered.length)
        ) { value, _, _ in
            if let attachment = value as? StubAttachment {
                found.append(attachment)
            }
        }
        return found
    }

    func testWithoutPluginsDollarSignsStayLiteralText() {
        let rendered = render("a $x^2$ b", plugins: [])
        XCTAssertTrue(rendered.string.contains("a $x^2$ b"))
    }

    func testPluginEnablesParsingAndClaimsNodes() {
        let rendered = render("a $x$ b", plugins: [mathStubPlugin])

        XCTAssertEqual(stubAttachments(in: rendered).count, 1)
        XCTAssertTrue(rendered.string.contains("\u{FFFC}"))
        XCTAssertFalse(rendered.string.contains("$"))
    }

    func testPluginOverridesBuiltInRenderer() {
        let plugin = StubPlugin(claimed: [.code], makeRenderer: { MarkerTextRenderer() })
        let rendered = render("before `code` after", plugins: [plugin])

        XCTAssertTrue(rendered.string.contains("[plugin]"))
        XCTAssertFalse(rendered.string.contains("code"))
    }

    func testUnclaimedNodesUseBuiltIns() {
        let rendered = render("**bold** and $x$", plugins: [mathStubPlugin])
        XCTAssertTrue(rendered.string.contains("bold"))
    }

    func testInlinePluginAttachmentExtraction() {
        let rendered = render("a $x$ b", plugins: [mathStubPlugin])
        let extracted = MarkdownExtractor.extractMarkdown(
            from: rendered,
            in: NSRange(location: 0, length: rendered.length)
        )
        XCTAssertEqual(extracted?.trimmingCharacters(in: .whitespacesAndNewlines), "a $stub$ b")
    }

    func testBlockPluginAttachmentExtractionWrapsBlankLines() {
        let rendered = render("before\n\n$$x$$\n\nafter", plugins: [mathStubPlugin])

        XCTAssertEqual(stubAttachments(in: rendered).first?.isBlock, true)

        let extracted = MarkdownExtractor.extractMarkdown(
            from: rendered,
            in: NSRange(location: 0, length: rendered.length)
        )
        XCTAssertEqual(
            extracted?.trimmingCharacters(in: .whitespacesAndNewlines),
            "before\n\n$stub$\n\nafter"
        )
    }

    func testPluginAttachmentDropsLineHeightCap() {
        config.paragraph.lineHeight = 20

        let plain = render("plain text", plugins: [mathStubPlugin])
        let withAttachment = render("with $x$ math", plugins: [mathStubPlugin])

        XCTAssertEqual(paragraphStyle(in: plain)?.maximumLineHeight, 20)
        XCTAssertEqual(paragraphStyle(in: withAttachment)?.maximumLineHeight, 0)
        XCTAssertEqual(paragraphStyle(in: withAttachment)?.minimumLineHeight, 20)
    }

    private func paragraphStyle(in rendered: NSAttributedString) -> NSParagraphStyle? {
        guard rendered.length > 0 else { return nil }
        return rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
    }
}
