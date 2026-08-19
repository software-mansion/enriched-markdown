import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class InlineStyleRendererTests: XCTestCase {
    private var config: MarkdownStyleConfig!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.baseline()
    }

    // MARK: - Strikethrough

    func testStrikethroughAppliesStrikethroughStyle() {
        let result = MarkdownRenderer.render("~~strike~~ plain", config: config)
        XCTAssertTrue(result.string.contains("strike"))

        assertLineStyle(.strikethroughStyle, in: result, onWord: "strike")
        assertNoLineStyle(.strikethroughStyle, in: result, onWord: "plain")
    }

    func testStrikethroughColorOverride() {
        var coloredConfig = config!
        coloredConfig.strikethrough.foregroundColor = .systemRed

        let result = MarkdownRenderer.render("~~strike~~", config: coloredConfig)

        let range = rangeOfWord("strike", in: result)
        let color = result.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, .systemRed)
    }

    func testStrikethroughPreservesBoldTrait() {
        let result = MarkdownRenderer.render("~~**both**~~", config: config)

        let range = rangeOfWord("both", in: result)
        let font = result.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        assertLineStyle(.strikethroughStyle, in: result, onWord: "both")
    }

    // MARK: - Underline

    func testUnderscoreIsEmphasisWithoutUnderlineFlag() {
        let result = MarkdownRenderer.render("_italic_", config: config)

        let range = rangeOfWord("italic", in: result)
        let font = result.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true)
        assertNoLineStyle(.underlineStyle, in: result, onWord: "italic")
    }

    func testUnderscoreRendersUnderlineWithFlag() {
        let flags = Md4cFlags(underline: true)
        let result = MarkdownRenderer.render("_under_", config: config, flags: flags)

        let range = rangeOfWord("under", in: result)
        let font = result.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
        XCTAssertFalse(font?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true)
        assertLineStyle(.underlineStyle, in: result, onWord: "under")
    }

    func testDoubleUnderscoreRendersUnderlineNotBoldWithFlag() {
        let flags = Md4cFlags(underline: true)
        let result = MarkdownRenderer.render("__under__", config: config, flags: flags)

        let range = rangeOfWord("under", in: result)
        let font = result.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
        XCTAssertFalse(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        assertLineStyle(.underlineStyle, in: result, onWord: "under")
    }

    func testParserEmitsUnderlineNodeOnlyWithFlag() {
        let withFlag = Parser.shared.parseMarkdown("_under_", flags: Md4cFlags(underline: true))
        XCTAssertNotNil(withFlag.first(ofType: .underline))
        XCTAssertNil(withFlag.first(ofType: .emphasis))

        let withoutFlag = Parser.shared.parseMarkdown("_under_")
        XCTAssertNil(withoutFlag.first(ofType: .underline))
        XCTAssertNotNil(withoutFlag.first(ofType: .emphasis))
    }

    // MARK: - Theme resolution

    func testStrikethroughAndUnderlineThemeElementsResolve() {
        let theme = MarkdownTheme {
            Strikethrough()
                .foregroundStyle(Color.red)
            Underline()
                .foregroundStyle(Color.blue)
        }
        let resolved = MarkdownStyleConfig.resolve(layers: [theme], traitCollection: .current)

        XCTAssertNotNil(resolved.strikethrough.foregroundColor)
        XCTAssertNotNil(resolved.underline.foregroundColor)
    }

    // MARK: - Helpers

    private func rangeOfWord(_ word: String, in attributed: NSAttributedString) -> NSRange {
        let range = (attributed.string as NSString).range(of: word)
        XCTAssertNotEqual(range.location, NSNotFound, "expected '\(word)' in rendered output")
        return range
    }

    private func assertLineStyle(
        _ key: NSAttributedString.Key,
        in attributed: NSAttributedString,
        onWord word: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let range = rangeOfWord(word, in: attributed)
        let value = attributed.attribute(key, at: range.location, effectiveRange: nil) as? Int
        XCTAssertEqual(value, NSUnderlineStyle.single.rawValue, file: file, line: line)
    }

    private func assertNoLineStyle(
        _ key: NSAttributedString.Key,
        in attributed: NSAttributedString,
        onWord word: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let range = rangeOfWord(word, in: attributed)
        let value = attributed.attribute(key, at: range.location, effectiveRange: nil) as? Int
        XCTAssertTrue(value == nil || value == 0, file: file, line: line)
    }
}
