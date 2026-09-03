import Combine
import UIKit
import XCTest
@testable import EnrichedMarkdown

private final class StubAttachment: NSTextAttachment, MarkdownPluginAttachment {
    let markdown: String
    let isBlock: Bool
    let literalText: String
    let sourceDelimiters: (opening: String, closing: String)?

    init(markdown: String, isBlock: Bool, literalText: String, delimiter: String) {
        self.markdown = markdown
        self.isBlock = isBlock
        self.literalText = literalText
        self.sourceDelimiters = (delimiter, delimiter)
        super.init(data: nil, ofType: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func markdownText() -> String { markdown }
}

/// Emits a stub attachment the way a real plugin renderer would: block-ness
/// from the context, literal text from the node, and a source-range tag.
private final class StubAttachmentRenderer: NodeRenderer {
    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        var attributes = context.getTextAttributes()
        attributes[.attachment] = StubAttachment(
            markdown: "$stub$",
            isBlock: context.rendersPluginBlock,
            literalText: node.flattenedText(),
            delimiter: node.type == .latexMathDisplay ? "$$" : "$"
        )
        SourceOffsetAnnotator.tagSourceRange(in: &attributes, of: node)
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

    /// Copy as Markdown for the rendered selection matching `substring`.
    private func copyMarkdown(
        selecting substring: String,
        in source: String,
        plugins: [any MarkdownRenderPlugin],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> String? {
        let rendered = render(source, plugins: plugins)
        let range = (rendered.string as NSString).range(of: substring)
        XCTAssertNotEqual(range.location, NSNotFound, "'\(substring)' not rendered", file: file, line: line)
        guard range.location != NSNotFound else { return nil }
        return MarkdownExtractor.markdown(for: range, in: rendered, sourceMarkdown: source, flags: effectiveFlags)
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

    // MARK: - Verbatim copy through the plugin seam

    private var effectiveFlags: Md4cFlags {
        MarkdownRenderer.effectiveFlags(.commonMark, plugins: [mathStubPlugin])
    }

    func testEffectiveFlagsApplyPluginAdjustments() {
        XCTAssertFalse(Md4cFlags.commonMark.latexMathEnabled)
        XCTAssertTrue(effectiveFlags.latexMathEnabled)
    }

    func testPartialSelectionWithPluginAttachmentCopiesVerbatim() {
        XCTAssertEqual(
            copyMarkdown(selecting: "a \u{FFFC} b", in: "a $x$ b and more", plugins: [mathStubPlugin]),
            "a $x$ b"
        )
    }

    func testPartialSelectionWithBlockPluginAttachmentKeepsDelimiterLines() {
        let source = "before\n\n$$\nx\n$$\n\nafter"
        let rendered = render(source, plugins: [mathStubPlugin])

        let afterLocation = (rendered.string as NSString).range(of: "after").location
        let copied = MarkdownExtractor.markdown(
            for: NSRange(location: 0, length: afterLocation),
            in: rendered,
            sourceMarkdown: source,
            flags: effectiveFlags
        )
        XCTAssertEqual(copied, "before\n\n$$\nx\n$$")
    }

    // The core flattens each line break plus its indentation inside a math
    // body to one space; the annotator must still anchor the node.
    func testIndentedBlockPluginAttachmentCopiesVerbatim() {
        let source = "before\n\n$$\n  x\n    + y\n$$\n\nafter"
        let rendered = render(source, plugins: [mathStubPlugin])

        let afterLocation = (rendered.string as NSString).range(of: "after").location
        let copied = MarkdownExtractor.markdown(
            for: NSRange(location: 0, length: afterLocation),
            in: rendered,
            sourceMarkdown: source,
            flags: effectiveFlags
        )
        XCTAssertEqual(copied, "before\n\n$$\n  x\n    + y\n$$")
    }

    func testMissingDelimiterAtSelectionEdgeFallsBackToReconstruction() {
        // A stub attachment claiming `$` delimiters on a node whose source
        // has none must not produce a slice when it bounds the selection.
        let plugin = StubPlugin(claimed: [.code], makeRenderer: { StubAttachmentRenderer() })
        XCTAssertEqual(copyMarkdown(selecting: "\u{FFFC}", in: "a `x` b", plugins: [plugin]), "$stub$")
    }

    func testInlinePluginReconstructionKeepsListPrefixAndMarkers() {
        let rendered = render("- **$x$** item", plugins: [mathStubPlugin])
        let extracted = MarkdownExtractor.extractMarkdown(
            from: rendered,
            in: NSRange(location: 0, length: rendered.length)
        )
        XCTAssertEqual(extracted?.trimmingCharacters(in: .whitespacesAndNewlines), "- **$stub$** item")
    }

    @MainActor
    func testRenderStoreRecordsPluginAdjustedFlags() {
        let store = MarkdownRenderStore()
        let rendered = expectation(description: "render applied")
        var recorded: RenderedSource?
        let subscription = store.$source.compactMap { $0 }.first().sink { source in
            recorded = source
            rendered.fulfill()
        }

        store.schedule(markdown: "a $x$ b", config: config, plugins: [mathStubPlugin])
        wait(for: [rendered], timeout: 5)
        subscription.cancel()

        XCTAssertEqual(recorded?.flags.latexMathEnabled, true)
    }

    func testPluginAttachmentDropsLineHeightCap() {
        config.paragraph.lineHeight = 20

        let plain = render("plain text", plugins: [mathStubPlugin])
        let withAttachment = render("with $x$ math", plugins: [mathStubPlugin])

        XCTAssertEqual(paragraphStyle(in: plain)?.maximumLineHeight, 20)
        XCTAssertEqual(paragraphStyle(in: withAttachment)?.maximumLineHeight, 0)
        XCTAssertEqual(paragraphStyle(in: withAttachment)?.minimumLineHeight, 20)

        // Blocks that re-apply their own line height keep the exemption.
        config.blockquote.lineHeight = 20
        let quoted = render("> with $x$ math", plugins: [mathStubPlugin])
        let formula = (quoted.string as NSString).range(of: "\u{FFFC}").location
        let quotedStyle = quoted.attribute(.paragraphStyle, at: formula, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(quotedStyle?.maximumLineHeight, 0)
    }

    private func paragraphStyle(in rendered: NSAttributedString) -> NSParagraphStyle? {
        guard rendered.length > 0 else { return nil }
        return rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
    }
}
