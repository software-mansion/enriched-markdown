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

    // MARK: - Superscript / subscript

    func testCaretAndTildeRenderLiterallyWithoutFlags() {
        let result = MarkdownRenderer.render("x^2^ H~2~O", config: config)
        XCTAssertTrue(result.string.contains("x^2^"))
        XCTAssertTrue(result.string.contains("H~2~O"))
    }

    func testParserEmitsSuperscriptAndSubscriptNodesOnlyWithFlags() {
        let withFlags = Parser.shared.parseMarkdown(
            "x^2^ H~2~O",
            flags: Md4cFlags(superscript: true, subscript: true)
        )
        XCTAssertNotNil(withFlags.first(ofType: .superscript))
        XCTAssertNotNil(withFlags.first(ofType: .subscript))

        let withoutFlags = Parser.shared.parseMarkdown("x^2^ H~2~O")
        XCTAssertNil(withoutFlags.first(ofType: .superscript))
        XCTAssertNil(withoutFlags.first(ofType: .subscript))
    }

    // Baseline offsets are asserted relative to the surrounding text because
    // line-height centering may give every run a shared base offset.
    func testSuperscriptShrinksFontAndRaisesBaseline() {
        let result = MarkdownRenderer.render("x^2^", config: config, flags: Md4cFlags(superscript: true))
        XCTAssertFalse(result.string.contains("^"))

        let baseSize = fontSize(onWord: "x", in: result)
        XCTAssertEqual(fontSize(onWord: "2", in: result), baseSize * 0.75, accuracy: 0.001)

        let relativeOffset = baselineOffset(onWord: "2", in: result) - baselineOffset(onWord: "x", in: result)
        XCTAssertEqual(relativeOffset, baseSize * 0.35, accuracy: 0.001)
    }

    func testSubscriptShrinksFontAndLowersBaseline() {
        let result = MarkdownRenderer.render("H~2~O", config: config, flags: Md4cFlags(subscript: true))
        XCTAssertFalse(result.string.contains("~"))

        let baseSize = fontSize(onWord: "H", in: result)
        XCTAssertEqual(fontSize(onWord: "2", in: result), baseSize * 0.75, accuracy: 0.001)

        let relativeOffset = baselineOffset(onWord: "2", in: result) - baselineOffset(onWord: "H", in: result)
        XCTAssertEqual(relativeOffset, -baseSize * 0.20, accuracy: 0.001)
    }

    func testSuperscriptPreservesBoldTrait() {
        let result = MarkdownRenderer.render(
            "x^**2**^",
            config: config,
            flags: Md4cFlags(superscript: true)
        )

        let range = rangeOfWord("2", in: result)
        let font = result.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        XCTAssertEqual(font?.pointSize ?? 0, fontSize(onWord: "x", in: result) * 0.75, accuracy: 0.001)
    }

    func testSuperscriptAndSubscriptStyleOverrides() {
        var scaledConfig = config!
        scaledConfig.superscript.fontScale = 0.5
        scaledConfig.superscript.baselineOffsetScale = 0.6
        scaledConfig.subscript.fontScale = 0.4
        scaledConfig.subscript.baselineOffsetScale = 0.3

        let flags = Md4cFlags(superscript: true, subscript: true)
        let result = MarkdownRenderer.render("a^s^ b~t~", config: scaledConfig, flags: flags)

        let baseSize = fontSize(onWord: "a", in: result)
        let baseOffset = baselineOffset(onWord: "a", in: result)

        XCTAssertEqual(fontSize(onWord: "s", in: result), baseSize * 0.5, accuracy: 0.001)
        XCTAssertEqual(baselineOffset(onWord: "s", in: result) - baseOffset, baseSize * 0.6, accuracy: 0.001)

        XCTAssertEqual(fontSize(onWord: "t", in: result), baseSize * 0.4, accuracy: 0.001)
        XCTAssertEqual(baselineOffset(onWord: "t", in: result) - baseOffset, -baseSize * 0.3, accuracy: 0.001)
    }

    // MARK: - Highlight

    func testEqualsRenderLiterallyWithoutFlag() {
        let result = MarkdownRenderer.render("==marked== plain", config: config)
        XCTAssertTrue(result.string.contains("==marked=="))

        let withoutFlag = Parser.shared.parseMarkdown("==marked==")
        XCTAssertNil(withoutFlag.first(ofType: .highlight))
    }

    func testHighlightAppliesBackgroundAndMarkerOnlyToSpan() {
        var highlightConfig = config!
        highlightConfig.highlight.backgroundColor = .systemYellow

        let result = MarkdownRenderer.render(
            "==marked== plain",
            config: highlightConfig,
            flags: Md4cFlags(highlight: true)
        )

        XCTAssertEqual(backgroundColor(onWord: "marked", in: result), .systemYellow)
        XCTAssertTrue(MarkdownAttributeValue.boolValue(from: attribute(MarkdownAttribute.highlight, onWord: "marked", in: result)))
        XCTAssertNil(backgroundColor(onWord: "plain", in: result))
        XCTAssertNil(attribute(MarkdownAttribute.highlight, onWord: "plain", in: result))
    }

    func testHighlightInheritsTextColorUnlessOverridden() {
        let flags = Md4cFlags(highlight: true)
        let inherited = MarkdownRenderer.render("==marked==", config: config, flags: flags)
        XCTAssertEqual(foregroundColor(onWord: "marked", in: inherited), config.paragraph.foregroundColor)

        var coloredConfig = config!
        coloredConfig.highlight.foregroundColor = .systemRed
        let overridden = MarkdownRenderer.render("==marked==", config: coloredConfig, flags: flags)
        XCTAssertEqual(foregroundColor(onWord: "marked", in: overridden), .systemRed)
    }

    func testHighlightPreservesBoldAndInlineCode() {
        var highlightConfig = config!
        highlightConfig.highlight.backgroundColor = .systemYellow
        highlightConfig.code.backgroundColor = .systemGray

        let result = MarkdownRenderer.render(
            "==**both** and `code`==",
            config: highlightConfig,
            flags: Md4cFlags(highlight: true)
        )

        let font = attribute(.font, onWord: "both", in: result) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        XCTAssertEqual(backgroundColor(onWord: "both", in: result), .systemYellow)
        XCTAssertEqual(backgroundColor(onWord: "code", in: result), .systemGray)
    }

    func testHighlightedLinkKeepsLinkColorOnHighlightBackground() {
        var highlightConfig = config!
        highlightConfig.highlight.backgroundColor = .systemYellow
        highlightConfig.highlight.foregroundColor = .systemRed
        highlightConfig.link.foregroundColor = .systemBlue

        let result = MarkdownRenderer.render(
            "==[press](https://swmansion.com)==",
            config: highlightConfig,
            flags: Md4cFlags(highlight: true)
        )

        XCTAssertEqual(backgroundColor(onWord: "press", in: result), .systemYellow)
        XCTAssertEqual(foregroundColor(onWord: "press", in: result), .systemBlue)
    }

    // MARK: - Theme resolution

    func testHighlightThemeElementResolves() {
        let theme = MarkdownTheme {
            Highlight()
                .foregroundStyle(Color.black)
                .background(Color.yellow)
        }
        let resolved = MarkdownStyleConfig.resolve(layers: [theme], traitCollection: .current)

        XCTAssertNotNil(resolved.highlight.foregroundColor)
        XCTAssertNotNil(resolved.highlight.backgroundColor)
    }

    func testDefaultThemeGivesHighlightABackground() {
        let resolved = MarkdownStyleConfig.baseline()
        XCTAssertNotNil(resolved.highlight.backgroundColor)
        XCTAssertNil(resolved.highlight.foregroundColor)
    }

    func testSuperscriptAndSubscriptThemeElementsResolve() {
        let theme = MarkdownTheme {
            Superscript()
                .fontScale(0.6)
                .baselineOffsetScale(0.4)
            Subscript()
                .fontScale(0.55)
                .baselineOffsetScale(0.25)
        }
        let resolved = MarkdownStyleConfig.resolve(layers: [theme], traitCollection: .current)

        XCTAssertEqual(resolved.superscript.fontScale, 0.6)
        XCTAssertEqual(resolved.superscript.baselineOffsetScale, 0.4)
        XCTAssertEqual(resolved.subscript.fontScale, 0.55)
        XCTAssertEqual(resolved.subscript.baselineOffsetScale, 0.25)
    }

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

    private func fontSize(onWord word: String, in attributed: NSAttributedString) -> CGFloat {
        let font = attribute(.font, onWord: word, in: attributed) as? UIFont
        XCTAssertNotNil(font, "expected a font on '\(word)'")
        return font?.pointSize ?? 0
    }

    private func attribute(_ key: NSAttributedString.Key, onWord word: String, in attributed: NSAttributedString) -> Any? {
        let range = rangeOfWord(word, in: attributed)
        return attributed.attribute(key, at: range.location, effectiveRange: nil)
    }

    private func backgroundColor(onWord word: String, in attributed: NSAttributedString) -> UIColor? {
        attribute(.backgroundColor, onWord: word, in: attributed) as? UIColor
    }

    private func foregroundColor(onWord word: String, in attributed: NSAttributedString) -> UIColor? {
        attribute(.foregroundColor, onWord: word, in: attributed) as? UIColor
    }

    private func baselineOffset(onWord word: String, in attributed: NSAttributedString) -> CGFloat {
        let offset = attribute(.baselineOffset, onWord: word, in: attributed) as? NSNumber
        return CGFloat(offset?.doubleValue ?? 0)
    }

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
