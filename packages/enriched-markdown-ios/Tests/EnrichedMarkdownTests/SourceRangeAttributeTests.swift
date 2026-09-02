import XCTest
@testable import EnrichedMarkdown

final class SourceRangeAttributeTests: XCTestCase {
    private var config: MarkdownStyleConfig!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.baseline()
    }

    /// Slices the source's UTF-8 bytes with a run's sourceRange value.
    private func sourceSlice(_ source: String, _ value: Any?) -> String? {
        guard let range = (value as? NSValue)?.rangeValue else { return nil }
        let bytes = Array(source.utf8)[range.location..<NSMaxRange(range)]
        return String(bytes: bytes, encoding: .utf8)
    }

    private func sourceRangeValue(
        forRun runText: String,
        in rendered: NSAttributedString
    ) -> Any? {
        let nsString = rendered.string as NSString
        let runRange = nsString.range(of: runText)
        guard runRange.location != NSNotFound else { return nil }
        return rendered.attribute(MarkdownAttribute.sourceRange, at: runRange.location, effectiveRange: nil)
    }

    func testPlainTextRunCarriesItsSourceRange() {
        let source = "Hello world"
        let rendered = MarkdownRenderer.render(source, config: config)

        let value = sourceRangeValue(forRun: "Hello world", in: rendered)
        XCTAssertEqual(sourceSlice(source, value), "Hello world")
    }

    func testStyledRunRangeExcludesMarkers() {
        let source = "hello **bold** world"
        let rendered = MarkdownRenderer.render(source, config: config)

        guard let value = sourceRangeValue(forRun: "bold", in: rendered),
              let range = (value as? NSValue)?.rangeValue else {
            return XCTFail("expected a sourceRange on the bold run")
        }
        XCTAssertEqual(range, NSRange(location: 8, length: 4))
        XCTAssertEqual(sourceSlice(source, value), "bold")
    }

    func testLinkLabelRunPointsAtLabelNotDestination() {
        let source = "see [docs](https://example.com) here"
        let rendered = MarkdownRenderer.render(source, config: config)

        let value = sourceRangeValue(forRun: "docs", in: rendered)
        XCTAssertEqual(sourceSlice(source, value), "docs")
    }

    func testEscapedRunSourceRangeCoversEscapedForm() {
        let source = "a\\*b"
        let rendered = MarkdownRenderer.render(source, config: config)

        let value = sourceRangeValue(forRun: "a*b", in: rendered)
        XCTAssertEqual(sourceSlice(source, value), "a\\*b")
    }

    func testSourceRangeUsesUTF8ByteOffsets() {
        let source = "ż **ó** ł"
        let rendered = MarkdownRenderer.render(source, config: config)

        guard let value = sourceRangeValue(forRun: "ó", in: rendered),
              let range = (value as? NSValue)?.rangeValue else {
            return XCTFail("expected a sourceRange on the bold run")
        }
        // "ż" is two UTF-8 bytes, so "ó" starts at byte 5 after "ż **".
        XCTAssertEqual(range, NSRange(location: 5, length: 2))
        XCTAssertEqual(sourceSlice(source, value), "ó")
    }

    func testSecondOccurrenceMapsToItsOwnPosition() {
        let source = "echo **echo**"
        let rendered = MarkdownRenderer.render(source, config: config)

        let nsString = rendered.string as NSString
        let firstRange = nsString.range(of: "echo")
        let secondRange = nsString.range(
            of: "echo",
            options: [],
            range: NSRange(
                location: NSMaxRange(firstRange),
                length: nsString.length - NSMaxRange(firstRange)
            )
        )
        guard firstRange.location != NSNotFound, secondRange.location != NSNotFound else {
            return XCTFail("expected two rendered echo runs")
        }

        let firstValue = rendered.attribute(
            MarkdownAttribute.sourceRange, at: firstRange.location, effectiveRange: nil
        )
        let secondValue = rendered.attribute(
            MarkdownAttribute.sourceRange, at: secondRange.location, effectiveRange: nil
        )
        // The first text node is "echo " — trailing space included.
        XCTAssertEqual((firstValue as? NSValue)?.rangeValue, NSRange(location: 0, length: 5))
        XCTAssertEqual((secondValue as? NSValue)?.rangeValue, NSRange(location: 7, length: 4))
    }
}
