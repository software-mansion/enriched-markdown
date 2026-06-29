import CoreText
import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class RendererTests: XCTestCase {
    private var config: MarkdownStyleConfig!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.baseline()
    }


    func testPlainTextUsesParagraphFont() {
        // marginBottom appends a spacer newline for UITextView layout; this test checks font only.
        var fontTestConfig = config!
        fontTestConfig.paragraph.marginBottom = nil

        let expectedFont = fontTestConfig.paragraph.font ?? UIFont.preferredFont(forTextStyle: .body)
        let result = MarkdownRenderer.render("Hello world", config: fontTestConfig)
        XCTAssertEqual(result.string, "Hello world")

        let textRange = NSRange(location: 0, length: "Hello world".utf16.count)
        var foundParagraphFont = false
        result.enumerateAttribute(.font, in: textRange) { value, range, _ in
            guard let font = value as? UIFont else { return }
            XCTAssertEqual(font.pointSize, expectedFont.pointSize)
            XCTAssertEqual(font.fontName, expectedFont.fontName)
            XCTAssertFalse(font.fontDescriptor.symbolicTraits.contains(.traitBold))
            XCTAssertFalse(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
            if range.length == textRange.length {
                foundParagraphFont = true
            }
        }
        XCTAssertTrue(foundParagraphFont)
    }


    func testBoldTextHasBoldTrait() {
        let result = MarkdownRenderer.render("**bold**", config: config)
        XCTAssertTrue(result.string.contains("bold"))

        var foundBold = false
        result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let font = value as? UIFont else { return }
            if result.string[range] == "bold" {
                XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold))
                foundBold = true
            }
        }
        XCTAssertTrue(foundBold)
    }


    func testItalicTextHasItalicTrait() {
        let result = MarkdownRenderer.render("*italic*", config: config)
        XCTAssertTrue(result.string.contains("italic"))

        var foundItalic = false
        result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let font = value as? UIFont else { return }
            if result.string[range] == "italic" {
                XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
                foundItalic = true
            }
        }
        XCTAssertTrue(foundItalic)
    }


    func testBoldAndItalicCombined() {
        let result = MarkdownRenderer.render("***both***", config: config)

        var foundBoth = false
        result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let font = value as? UIFont else { return }
            if result.string[range] == "both" {
                let traits = font.fontDescriptor.symbolicTraits
                XCTAssertTrue(traits.contains(.traitBold))
                XCTAssertTrue(traits.contains(.traitItalic))
                foundBoth = true
            }
        }
        XCTAssertTrue(foundBoth)
    }


    func testThemeOverrideAppliesStrongColor() {
        var customConfig = config!
        customConfig.strong.foregroundColor = .systemRed

        let result = MarkdownRenderer.render("**bold**", config: customConfig)

        var foundRed = false
        result.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let color = value as? UIColor else { return }
            if result.string[range] == "bold" {
                XCTAssertEqual(color, UIColor.systemRed)
                foundRed = true
            }
        }
        XCTAssertTrue(foundRed)
    }


    func testMultipleParagraphsPreserveStructure() {
        let result = MarkdownRenderer.render("First\n\nSecond", config: config)
        XCTAssertTrue(result.string.contains("First"))
        XCTAssertTrue(result.string.contains("Second"))
        XCTAssertTrue(result.string.contains("\n"))
    }


    func testNestedBoldWithItalicInside() {
        let result = MarkdownRenderer.render("**bold *italic* bold**", config: config)
        XCTAssertTrue(result.string.contains("italic"))

        var italicFound = false
        result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let font = value as? UIFont else { return }
            let substring = (result.string as NSString).substring(with: range)
            if substring.contains("italic") {
                XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
                italicFound = true
            }
        }
        XCTAssertTrue(italicFound)
    }


    func testTopLevelParagraphMarginBottomUsesParagraphSpacing() {
        var customConfig = config!
        customConfig.paragraph.marginBottom = 80

        let result = MarkdownRenderer.render("First paragraph.\n\nSecond paragraph.", config: customConfig)

        let firstParagraph = (result.string as NSString).range(of: "First paragraph.")
        XCTAssertNotEqual(firstParagraph.location, NSNotFound)

        let style = result.attribute(.paragraphStyle, at: firstParagraph.location, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.paragraphSpacing, 80)
    }


    func testParagraphUsesConfiguredLineHeight() {
        let result = MarkdownRenderer.render("Hello world", config: config)

        let style = result.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.minimumLineHeight, 26)
        XCTAssertEqual(style?.maximumLineHeight, 26)

        let baselineOffset = result.attribute(.baselineOffset, at: 0, effectiveRange: nil) as? CGFloat
        XCTAssertNotNil(baselineOffset)
        XCTAssertGreaterThan(baselineOffset ?? 0, 0)
    }


    func testHeadingUsesLargerFontThanBody() {
        let result = MarkdownRenderer.render("# Heading", config: config)
        XCTAssertTrue(result.string.contains("Heading"))

        let bodyFont = config.paragraph.font ?? UIFont.preferredFont(forTextStyle: .body)
        var effectiveRange = NSRange()
        let attributes = result.attributes(at: 0, effectiveRange: &effectiveRange)
        let headingFont = attributes[.font] as? UIFont
        XCTAssertNotNil(headingFont)
        XCTAssertGreaterThan(headingFont!.pointSize, bodyFont.pointSize)
    }


    func testHeadingLevel2UsesConfiguredFont() {
        let result = MarkdownRenderer.render("## Sub", config: config)
        XCTAssertTrue(result.string.contains("Sub"))

        let expectedFont = config.heading2.font ?? UIFont.systemFont(ofSize: 24, weight: .regular)
        var effectiveRange = NSRange()
        let attributes = result.attributes(at: 0, effectiveRange: &effectiveRange)
        let font = attributes[.font] as? UIFont
        XCTAssertEqual(font?.pointSize, expectedFont.pointSize)
    }


    func testHeadingUsesBoldWeightInDefaultTheme() {
        let result = MarkdownRenderer.render("# Heading", config: config)

        var effectiveRange = NSRange()
        let attributes = result.attributes(at: 0, effectiveRange: &effectiveRange)
        let font = attributes[.font] as? UIFont
        XCTAssertNotNil(font)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitBold))
    }


    func testBoldInsideHeading() {
        let result = MarkdownRenderer.render("# **bold** heading", config: config)

        var boldFound = false
        result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let font = value as? UIFont else { return }
            let substring = (result.string as NSString).substring(with: range)
            if substring.contains("bold") {
                XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold))
                let headingFont = config.heading1.font ?? UIFont.systemFont(ofSize: 30, weight: .regular)
                XCTAssertGreaterThanOrEqual(font.pointSize, headingFont.pointSize)
                boldFound = true
            }
        }
        XCTAssertTrue(boldFound)
    }


    func testLinkHasURLAttribute() {
        let result = MarkdownRenderer.render("[text](https://example.com)", config: config)
        XCTAssertTrue(result.string.contains("text"))

        var foundLink = false
        result.enumerateAttribute(.link, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            let urlString: String?
            if let url = value as? URL {
                urlString = url.absoluteString
            } else {
                urlString = value as? String
            }
            guard let urlString else { return }
            let substring = (result.string as NSString).substring(with: range)
            if substring == "text" {
                XCTAssertEqual(urlString, "https://example.com")
                foundLink = true
            }
        }
        XCTAssertTrue(foundLink)
    }


    func testLinkThemeOverrideAppliesColor() {
        var customConfig = config!
        customConfig.link.foregroundColor = .systemBlue

        let result = MarkdownRenderer.render("[link](https://example.com)", config: customConfig)

        var foundBlue = false
        result.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let color = value as? UIColor else { return }
            if result.string[range] == "link" {
                XCTAssertEqual(color, UIColor.systemBlue)
                foundBlue = true
            }
        }
        XCTAssertTrue(foundBlue)
    }


    func testLinkInsideParagraphWithInlineStyles() {
        let result = MarkdownRenderer.render("**bold** and [link](https://example.com) and *italic*", config: config)
        XCTAssertTrue(result.string.contains("link"))

        var linkFound = false
        result.enumerateAttribute(.link, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard value != nil else { return }
            if result.string[range] == "link" {
                linkFound = true
            }
        }
        XCTAssertTrue(linkFound)
    }


    func testAllAttributeRangesWithinBounds() {
        let samples = [
            "# Heading one\n\n## Heading two\n\nA paragraph with a [link](https://example.com) and **bold** nearby.",
            Self.headingsAndLinksFixture,
            "Plain\n\n**bold**",
            "Line one  \nLine two",
            "Use `code` and **bold**",
            "![Mountain](https://example.com/img.png)",
            "Hello ![icon](https://example.com/icon.png) world",
            "---",
            "```\ncode\n```",
            "> quote",
            "- item",
            "1. ordered"
        ]

        for sample in samples {
            let result = MarkdownRenderer.render(sample, config: config)
            let length = result.length
            result.enumerateAttributes(in: NSRange(location: 0, length: length)) { _, range, _ in
                XCTAssertGreaterThanOrEqual(range.location, 0)
                XCTAssertLessThanOrEqual(NSMaxRange(range), length)
            }
        }
    }

    private static let headingsAndLinksFixture = """
    # Heading one

    ## Heading two

    A paragraph with a [link](https://example.com) and **bold** nearby.
    """
}

private extension String {
    subscript(range: NSRange) -> String {
        (self as NSString).substring(with: range)
    }
}
