import CoreText
import UIKit
import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownLaTeX

/// LaTeXRenderPlugin with a deterministic typeset function injected into
/// MathRenderer.
private struct StubTypesetPlugin: MarkdownRenderPlugin {
    let typeset: MathRenderer.Typeset

    func renderer(for type: NodeType, config: MarkdownStyleConfig) -> NodeRenderer? {
        switch type {
        case .latexMathInline, .latexMathDisplay:
            return MathRenderer(config: config, typeset: typeset)
        default:
            return nil
        }
    }

    func adjustFlags(_ flags: inout Md4cFlags) {
        LaTeXRenderPlugin().adjustFlags(&flags)
    }

    var rootBlockNodeTypes: Set<NodeType> { LaTeXRenderPlugin().rootBlockNodeTypes }
}

final class LaTeXRenderingTests: XCTestCase {
    private var config: MarkdownStyleConfig!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.baseline()
    }

    // MARK: - Helpers

    private func renderWithStub(
        _ markdown: String,
        typeset: @escaping MathRenderer.Typeset
    ) -> NSAttributedString {
        MarkdownRenderer.render(
            markdown,
            config: config,
            flags: .commonMark,
            imageRequestHeaders: [:],
            plugins: [StubTypesetPlugin(typeset: typeset)]
        )
    }

    private func stubResult() -> MathTypesetResult {
        MathTypesetResult(width: 40, ascent: 12, descent: 4) { _ in }
    }

    private func mathAttachments(in rendered: NSAttributedString) -> [MathAttachment] {
        var found: [MathAttachment] = []
        rendered.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: rendered.length)
        ) { value, _, _ in
            if let math = value as? MathAttachment {
                found.append(math)
            }
        }
        return found
    }

    // MARK: - Real engine

    // Guards the Fonts resource wiring (a symlink in the monorepo): an
    // unregistered font would make CoreText fall back to a different face.
    func testKaTeXFontsRegisterFromBundle() {
        _ = RaTeXFontLoader.ensureLoaded()

        let font = CTFontCreateWithName("KaTeX_Main-Regular" as CFString, 12, nil)
        XCTAssertEqual(CTFontCopyPostScriptName(font) as String, "KaTeX_Main-Regular")
    }

    func testRaTeXTypesetsSimpleFormula() {
        let result = MathRenderer.raTeXTypeset("x^2", displayMode: false, fontSize: 17, color: .black)

        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result?.width ?? 0, 0)
        XCTAssertGreaterThan(result?.ascent ?? 0, 0)
    }

    func testDisplayModeTypesetsTallerThanInline() {
        let inline = MathRenderer.raTeXTypeset(#"\frac{1}{2}"#, displayMode: false, fontSize: 17, color: .black)
        let display = MathRenderer.raTeXTypeset(#"\frac{1}{2}"#, displayMode: true, fontSize: 17, color: .black)

        guard let inline, let display else {
            return XCTFail("expected both modes to typeset")
        }
        XCTAssertGreaterThan(display.size.height, inline.size.height)
    }

    func testInvalidLatexReturnsNil() {
        XCTAssertNil(MathRenderer.raTeXTypeset(#"\frac{1}{"#, displayMode: false, fontSize: 17, color: .black))
    }

    func testDrawProducesNonBlankImage() {
        guard let result = MathRenderer.raTeXTypeset("x^2", displayMode: false, fontSize: 17, color: .black) else {
            return XCTFail("expected typeset result")
        }

        let size = CGSize(width: ceil(result.width), height: ceil(result.size.height))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            result.draw(context.cgContext)
        }

        XCTAssertFalse(isBlank(image))
    }

    func testRenderLaTeXProducesMathAttachmentWithoutFlagSetup() {
        let rendered = MarkdownRenderer.renderLaTeX("inline $x^2$ math", config: config)

        XCTAssertEqual(mathAttachments(in: rendered).count, 1)
        XCTAssertFalse(rendered.string.contains("$"))
    }

    // MARK: - Renderer behavior (stubbed typesetting)

    func testInlineAttachmentMetricsAndDelimiters() {
        var typesetFontSize: CGFloat?
        let rendered = renderWithStub("before $x^2$ after") { _, _, fontSize, _ in
            typesetFontSize = fontSize
            return self.stubResult()
        }

        let attachments = mathAttachments(in: rendered)
        XCTAssertEqual(attachments.count, 1)
        guard let math = attachments.first else { return }

        XCTAssertEqual(math.latex, "x^2")
        XCTAssertFalse(math.isDisplay)
        XCTAssertFalse(math.isBlock)
        XCTAssertEqual(math.accessibilityLabel, "x^2")
        XCTAssertEqual(math.markdownText(), "$x^2$")

        let expectedFontSize = (config.paragraph.font ?? UIFont.preferredFont(forTextStyle: .body)).pointSize
        XCTAssertEqual(typesetFontSize, expectedFontSize)

        let bounds = math.attachmentBounds(
            for: nil,
            proposedLineFragment: CGRect(x: 0, y: 0, width: 300, height: 20),
            glyphPosition: .zero,
            characterIndex: 0
        )
        XCTAssertEqual(bounds, CGRect(x: 0, y: -4, width: 40, height: 16))
    }

    func testRootLevelDisplayMathIsBlock() {
        let rendered = renderWithStub("before\n\n$$E=mc^2$$\n\nafter") { _, displayMode, _, _ in
            XCTAssertTrue(displayMode)
            return self.stubResult()
        }

        let attachments = mathAttachments(in: rendered)
        XCTAssertEqual(attachments.count, 1)
        XCTAssertEqual(attachments.first?.isDisplay, true)
        XCTAssertEqual(attachments.first?.isBlock, true)
        XCTAssertEqual(attachments.first?.markdownText(), "$$E=mc^2$$")
    }

    func testDisplayMathInsideParagraphStaysInline() {
        let rendered = renderWithStub("before $$x$$ after") { _, _, _, _ in self.stubResult() }

        let attachments = mathAttachments(in: rendered)
        XCTAssertEqual(attachments.count, 1)
        XCTAssertEqual(attachments.first?.isDisplay, true)
        XCTAssertEqual(attachments.first?.isBlock, false)
        XCTAssertTrue(rendered.string.contains("before \u{FFFC} after"))
    }

    func testTypesetFailureFallsBackToDelimitedSource() {
        let rendered = renderWithStub("$x^2$") { _, _, _, _ in nil }

        XCTAssertTrue(mathAttachments(in: rendered).isEmpty)
        XCTAssertTrue(rendered.string.contains("$x^2$"))
    }

    // MARK: - Copy as Markdown integration

    func testMathAttachmentRunCarriesSourceRange() {
        let source = "before $x^2$ after"
        let rendered = renderWithStub(source) { _, _, _, _ in self.stubResult() }

        let attachmentIndex = (rendered.string as NSString).range(of: "\u{FFFC}").location
        XCTAssertNotEqual(attachmentIndex, NSNotFound)

        let value = rendered.attribute(
            MarkdownAttribute.sourceRange,
            at: attachmentIndex,
            effectiveRange: nil
        ) as? NSValue
        XCTAssertNotNil(value)
        guard let byteRange = value?.rangeValue else { return }

        let bytes = Array(source.utf8)[byteRange.location..<byteRange.location + byteRange.length]
        XCTAssertEqual(Array(bytes), Array("x^2".utf8))
    }

    func testFullSelectionCopyReturnsVerbatimSource() {
        let source = "before\n\n$$\na + b\nc + d\n$$\n\nafter"
        let rendered = renderWithStub(source) { _, _, _, _ in self.stubResult() }

        let copied = MarkdownExtractor.markdown(
            for: NSRange(location: 0, length: rendered.length),
            in: rendered,
            sourceMarkdown: source,
            flags: .commonMark
        )
        XCTAssertEqual(copied, source)
    }

    private var effectiveFlags: Md4cFlags {
        MarkdownRenderer.effectiveFlags(.commonMark, plugins: [LaTeXRenderPlugin()])
    }

    func testPartialSelectionWithInlineMathCopiesVerbatim() {
        let source = "before $x^2$ and more text after"
        let rendered = renderWithStub(source) { _, _, _, _ in self.stubResult() }

        let partial = (rendered.string as NSString).range(of: "before \u{FFFC} and")
        XCTAssertNotEqual(partial.location, NSNotFound)

        let copied = MarkdownExtractor.markdown(
            for: partial,
            in: rendered,
            sourceMarkdown: source,
            flags: effectiveFlags
        )
        XCTAssertEqual(copied, "before $x^2$ and")
    }

    func testPartialSelectionKeepsMultiLineDisplayMathVerbatim() {
        let source = "before\n\n$$\na + b\nc + d\n$$\n\nafter"
        let rendered = renderWithStub(source) { _, _, _, _ in self.stubResult() }

        let afterLocation = (rendered.string as NSString).range(of: "after").location
        let copied = MarkdownExtractor.markdown(
            for: NSRange(location: 0, length: afterLocation),
            in: rendered,
            sourceMarkdown: source,
            flags: effectiveFlags
        )
        XCTAssertEqual(copied, "before\n\n$$\na + b\nc + d\n$$")
    }

    func testMathAtSelectionEdgeInsideEmphasisKeepsMarkers() {
        let source = "**$x^2$** after"
        let rendered = renderWithStub(source) { _, _, _, _ in self.stubResult() }

        let formula = (rendered.string as NSString).range(of: "\u{FFFC}")
        let copied = MarkdownExtractor.markdown(
            for: formula,
            in: rendered,
            sourceMarkdown: source,
            flags: effectiveFlags
        )
        XCTAssertEqual(copied, "**$x^2$**")
    }

    // The core flattens breaks inside math spans to spaces, which TeX treats
    // the same as newlines; both lines must reach the typesetter.
    func testMultiLineDisplayMathKeepsAllContent() {
        var receivedLatex: String?
        _ = renderWithStub("$$\na + b\nc + d\n$$") { latex, _, _, _ in
            receivedLatex = latex
            return self.stubResult()
        }

        XCTAssertTrue(receivedLatex?.contains("a + b") ?? false)
        XCTAssertTrue(receivedLatex?.contains("c + d") ?? false)
    }

    func testExtractionRoundTripsMathAttachments() {
        let inline = renderWithStub("before $x^2$ after") { _, _, _, _ in self.stubResult() }
        XCTAssertEqual(
            MarkdownExtractor.extractMarkdown(
                from: inline,
                in: NSRange(location: 0, length: inline.length)
            )?.trimmingCharacters(in: .whitespacesAndNewlines),
            "before $x^2$ after"
        )

        let block = renderWithStub("before\n\n$$E=mc^2$$\n\nafter") { _, _, _, _ in self.stubResult() }
        XCTAssertEqual(
            MarkdownExtractor.extractMarkdown(
                from: block,
                in: NSRange(location: 0, length: block.length)
            )?.trimmingCharacters(in: .whitespacesAndNewlines),
            "before\n\n$$E=mc^2$$\n\nafter"
        )
    }

    /// True when every pixel is fully transparent.
    private func isBlank(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return true }
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return true }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return !pixels.contains { $0 > 0 }
    }
}
