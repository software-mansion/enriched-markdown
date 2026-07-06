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
                XCTAssertTrue(Self.fontHasBoldAndItalic(font))
                foundBoth = true
            }
        }
        XCTAssertTrue(foundBoth)
    }


    private static func fontHasBoldAndItalic(_ font: UIFont) -> Bool {
        FontHelpers.hasBoldTrait(font) && FontHelpers.hasItalicTrait(font)
    }


    private static var registeredMontserratFonts = false


    private static func registerMontserratFontsIfNeeded() {
        guard !registeredMontserratFonts else { return }
        registeredMontserratFonts = true

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fontsDir = repoRoot
            .appendingPathComponent("apps/ios-example/EnrichedMarkdownExample/EnrichedMarkdownExample/Resources/Fonts")

        for name in ["Montserrat-Regular", "Montserrat-Bold", "Montserrat-Italic", "Montserrat-BoldItalic"] {
            let url = fontsDir.appendingPathComponent("\(name).ttf")
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }


    func testBoldAndItalicCombinedInCustomFontListItem() {
        Self.registerMontserratFontsIfNeeded()

        var themedConfig = config!
        var theme = MarkdownTheme {
            List().fontFamily("Montserrat-Regular", size: 16)
            Strong().foregroundStyle(Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255))
            Emphasis().foregroundStyle(Color(red: 75 / 255, green: 85 / 255, blue: 99 / 255))
        }
        theme.apply(to: &themedConfig, traitCollection: .current)

        let result = MarkdownRenderer.render(
            "- Natural water filtration and ***flood prevention***",
            config: themedConfig
        )

        var foundItalic = false
        result.enumerateAttributes(in: NSRange(location: 0, length: result.length)) { attrs, range, _ in
            let substring = (result.string as NSString).substring(with: range)
            guard substring.contains("flood prevention") else { return }
            guard let font = attrs[.font] as? UIFont else { return }

            XCTAssertEqual(font.fontName, "Montserrat-BoldItalic")
            foundItalic = true
        }
        XCTAssertTrue(foundItalic)
    }


    func testBoldAndItalicCombinedUsesItalicFaceForCustomBoldFont() {
        Self.registerMontserratFontsIfNeeded()
        guard let bold = UIFont(name: "Montserrat-Bold", size: 16) else {
            XCTFail("Montserrat-Bold not available")
            return
        }

        XCTAssertEqual(FontHelpers.ensureItalic(bold)?.fontName, "Montserrat-BoldItalic")
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


    func testCustomThemeHeadingUsesBoldFontFamily() {
        var themedConfig = config!
        var theme = MarkdownTheme {
            Heading(1).fontFamily("Helvetica-Bold", size: 30)
            Heading(2).fontFamily("Helvetica-Bold", size: 24)
        }
        theme.apply(to: &themedConfig, traitCollection: .current)

        let result = MarkdownRenderer.render("# Title\n\n## Subtitle", config: themedConfig)

        var foundBoldHeading = false
        result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let font = value as? UIFont else { return }
            let text = (result.string as NSString).substring(with: range)
            guard text == "Title" || text == "Subtitle" else { return }
            XCTAssertTrue(
                font.fontDescriptor.symbolicTraits.contains(.traitBold) || font.fontName.localizedCaseInsensitiveContains("bold")
            )
            foundBoldHeading = true
        }
        XCTAssertTrue(foundBoldHeading)
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


    func testHardLineBreakUsesLineSeparator() {
        let result = MarkdownRenderer.render("Line one  \nLine two", config: config)
        XCTAssertTrue(result.string.contains("Line one"))
        XCTAssertTrue(result.string.contains("Line two"))
        XCTAssertTrue(result.string.contains("\u{2028}"))

        let separatorRange = (result.string as NSString).range(of: "\u{2028}")
        XCTAssertNotEqual(separatorRange.location, NSNotFound)

        var effectiveRange = NSRange()
        let attributes = result.attributes(at: separatorRange.location, effectiveRange: &effectiveRange)
        XCTAssertNotNil(attributes[.font] as? UIFont)
    }


    func testInlineCodeUsesMonospacedFont() {
        let result = MarkdownRenderer.render("Use `code` here", config: config)
        XCTAssertTrue(result.string.contains("code"))

        var foundMonospaced = false
        result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let font = value as? UIFont else { return }
            if result.string[range] == "code" {
                XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
                foundMonospaced = true
            }
        }
        XCTAssertTrue(foundMonospaced)
    }


    func testInlineCodeHasInlineCodeAttribute() {
        let result = MarkdownRenderer.render("`code`", config: config)

        var found = false
        result.enumerateAttribute(MarkdownAttribute.inlineCode, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            if result.string[range] == "code", value as? Bool == true {
                found = true
            }
        }
        XCTAssertTrue(found)
    }


    func testInlineCodeAppliesBackgroundColor() {
        let result = MarkdownRenderer.render("`code`", config: config)

        var foundBackground = false
        result.enumerateAttribute(.backgroundColor, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            if result.string[range] == "code", value != nil {
                foundBackground = true
            }
        }
        XCTAssertTrue(foundBackground)
    }


    func testInlineCodeThemeOverrideAppliesColor() {
        var customConfig = config!
        customConfig.code.foregroundColor = .systemPink

        let result = MarkdownRenderer.render("`code`", config: customConfig)

        var foundPink = false
        result.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let color = value as? UIColor else { return }
            if result.string[range] == "code" {
                XCTAssertEqual(color, UIColor.systemPink)
                foundPink = true
            }
        }
        XCTAssertTrue(foundPink)
    }


    func testBoldInlineCodePreservesBoldWeight() {
        let result = MarkdownRenderer.render("**`code`**", config: config)

        var foundBoldMonospaced = false
        result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let font = value as? UIFont else { return }
            if result.string[range] == "code" {
                XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
                XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold))
                foundBoldMonospaced = true
            }
        }
        XCTAssertTrue(foundBoldMonospaced)
    }


    func testBlockImageInsertsAttachmentWithAltText() {
        let result = MarkdownRenderer.render("![Mountain](https://example.com/img.png)", config: config)

        var found = false
        result.enumerateAttribute(.attachment, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            guard let attachment = value as? MarkdownImageAttachment else { return }
            XCTAssertEqual(attachment.imageURL, "https://example.com/img.png")
            XCTAssertFalse(attachment.isInline)
            XCTAssertEqual(attachment.accessibilityLabel, "Mountain")
            XCTAssertEqual(attachment.cachedHeight, 200)
            found = true
        }
        XCTAssertTrue(found)
    }


    func testBlockImageAfterParagraphIsNotInline() {
        let result = MarkdownRenderer.render(
            "Hello world\n\n![Mountain](https://example.com/img.png)",
            config: config
        )

        var foundBlockImage = false
        result.enumerateAttribute(.attachment, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            guard let attachment = value as? MarkdownImageAttachment else { return }
            XCTAssertFalse(attachment.isInline)
            XCTAssertEqual(attachment.cachedHeight, 200)
            foundBlockImage = true
        }
        XCTAssertTrue(foundBlockImage)
    }


    func testInlineImageUsesInlineSize() {
        let result = MarkdownRenderer.render("Hello ![icon](https://example.com/icon.png) world", config: config)

        var found = false
        result.enumerateAttribute(.attachment, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            guard let attachment = value as? MarkdownImageAttachment else { return }
            XCTAssertTrue(attachment.isInline)
            XCTAssertEqual(attachment.cachedHeight, 20)
            found = true
        }
        XCTAssertTrue(found)
    }


    func testImageWithEmptyURLIsSkipped() {
        let result = MarkdownRenderer.render("![alt]()", config: config)

        var hasAttachment = false
        result.enumerateAttribute(.attachment, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if value != nil {
                hasAttachment = true
            }
        }
        XCTAssertFalse(hasAttachment)
    }


    func testThematicBreakInsertsAttachment() {
        let result = MarkdownRenderer.render("---", config: config!)

        XCTAssertTrue(result.string.contains("\u{FFFC}"))

        var foundAttachment = false
        result.enumerateAttribute(.attachment, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            guard value is NSTextAttachment else { return }
            foundAttachment = true
        }
        XCTAssertTrue(foundAttachment)
    }


    func testThematicBreakThemeOverride() {
        var customConfig = config!
        customConfig.thematicBreak.height = 3

        let result = MarkdownRenderer.render("---", config: customConfig)
        var found = false
        result.enumerateAttribute(.attachment, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            guard let attachment = value as? ThematicBreakAttachment else { return }
            XCTAssertEqual(attachment.lineHeight, 3)
            found = true
        }
        XCTAssertTrue(found)
    }


    func testCodeBlockHasMonospacedFontAndAttribute() {
        let result = MarkdownRenderer.render("```\ncode line\n```", config: config)

        var foundCodeBlock = false
        result.enumerateAttribute(MarkdownAttribute.codeBlock, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard (value as? Bool) == true else { return }
            XCTAssertTrue(result.string[range].contains("code"))
            foundCodeBlock = true
        }
        XCTAssertTrue(foundCodeBlock)

        var foundMonospaced = false
        result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let font = value as? UIFont else { return }
            if result.string[range].contains("code") {
                XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
                foundMonospaced = true
            }
        }
        XCTAssertTrue(foundMonospaced)
    }


    func testCodeBlockThemeOverride() {
        var customConfig = config!
        customConfig.codeBlock.foregroundColor = .systemGreen

        let result = MarkdownRenderer.render("```\ncode\n```", config: customConfig)
        var foundGreen = false
        result.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let color = value as? UIColor else { return }
            if result.string[range].contains("code") {
                XCTAssertEqual(color, UIColor.systemGreen)
                foundGreen = true
            }
        }
        XCTAssertTrue(foundGreen)
    }


    func testCodeBlockDoesNotIncludePrecedingParagraphLabel() {
        let result = MarkdownRenderer.render(
            "Fenced block:\n\n```\ncode\n```",
            config: config
        )

        var labelHasCodeBlock = false
        result.enumerateAttribute(MarkdownAttribute.codeBlock, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard value != nil else { return }
            if result.string[range].contains("Fenced block:") {
                labelHasCodeBlock = true
            }
        }
        XCTAssertFalse(labelHasCodeBlock)
    }


    func testCodeBlockBackgroundRangeIncludesPaddingSpacers() {
        var customConfig = config!
        customConfig.codeBlock.padding = 16
        customConfig.codeBlock.marginBottom = 0
        customConfig.codeBlock.marginTop = 0

        let result = MarkdownRenderer.render("```\ncode line\n```", config: customConfig)

        var codeBlockRange = NSRange(location: NSNotFound, length: 0)
        result.enumerateAttribute(MarkdownAttribute.codeBlock, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard (value as? Bool) == true else { return }
            codeBlockRange = range
        }
        XCTAssertNotEqual(codeBlockRange.location, NSNotFound)
        XCTAssertGreaterThanOrEqual(result.string[codeBlockRange].filter { $0 == "\n" }.count, 2)
        XCTAssertTrue(result.string[codeBlockRange].contains("code line"))
    }


    func testBlockquoteHasDepthAndIndent() {
        let result = MarkdownRenderer.render("> quote text", config: config)

        var foundDepth = false
        result.enumerateAttribute(MarkdownAttribute.blockquoteDepth, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let depth = value as? Int else { return }
            XCTAssertEqual(depth, 0)
            if let style = result.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle {
                XCTAssertGreaterThan(style.headIndent, 0)
            }
            foundDepth = true
        }
        XCTAssertTrue(foundDepth)
    }


    func testNestedBlockquoteIncreasesDepth() {
        let result = MarkdownRenderer.render("> outer\n> > inner", config: config)

        var depths = Set<Int>()
        result.enumerateAttribute(MarkdownAttribute.blockquoteDepth, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if let depth = value as? Int {
                depths.insert(depth)
            }
        }
        XCTAssertTrue(depths.contains(0))
        XCTAssertTrue(depths.contains(1))
    }


    func testNestedBlockquoteRendersOnSeparateLines() {
        let result = MarkdownRenderer.render("> Outer quote\n> > Nested quote", config: config)
        let outerRange = (result.string as NSString).range(of: "Outer quote")
        let nestedRange = (result.string as NSString).range(of: "Nested quote")
        XCTAssertNotEqual(outerRange.location, NSNotFound)
        XCTAssertNotEqual(nestedRange.location, NSNotFound)
        XCTAssertLessThan(outerRange.location, nestedRange.location)
    }


    func testBlockquoteDepthAttributeIsReadableAsInteger() {
        let result = MarkdownRenderer.render("> quote", config: config)
        var foundDepth = false
        result.enumerateAttribute(MarkdownAttribute.blockquoteDepth, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if MarkdownAttributeValue.intValue(from: value) == 0 {
                foundDepth = true
            }
        }
        XCTAssertTrue(foundDepth)
    }


    func testUnorderedListItemsHaveListAttributes() {
        let result = MarkdownRenderer.render("- first\n- second", config: config)

        var itemCount = 0
        result.enumerateAttribute(MarkdownAttribute.listItemNumber, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if value != nil { itemCount += 1 }
        }
        XCTAssertGreaterThanOrEqual(itemCount, 2)
    }


    func testOrderedListItemsHaveSequentialNumbers() {
        let result = MarkdownRenderer.render("1. first\n2. second", config: config)

        var numbers = Set<Int>()
        result.enumerateAttribute(MarkdownAttribute.listItemNumber, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if let number = value as? Int {
                numbers.insert(number)
            }
        }
        XCTAssertTrue(numbers.contains(1))
        XCTAssertTrue(numbers.contains(2))
    }


    func testListFirstItemAfterLabelHasListAttributes() {
        let result = MarkdownRenderer.render("Unordered:\n\n- Alpha\n- Beta", config: config)

        guard let alphaRange = (result.string as NSString).range(of: "Alpha") as NSRange?,
              alphaRange.location != NSNotFound else {
            XCTFail("Missing Alpha list item")
            return
        }

        let depth = MarkdownAttributeValue.intValue(
            from: result.attribute(MarkdownAttribute.listDepth, at: alphaRange.location, effectiveRange: nil)
        )
        let number = MarkdownAttributeValue.intValue(
            from: result.attribute(MarkdownAttribute.listItemNumber, at: alphaRange.location, effectiveRange: nil)
        )
        XCTAssertEqual(depth, 0)
        XCTAssertEqual(number, 1)

        let labelRange = (result.string as NSString).range(of: "Unordered:")
        let labelParagraph = (result.string as NSString).paragraphRange(for: labelRange)
        let alphaParagraph = (result.string as NSString).paragraphRange(for: alphaRange)
        XCTAssertNotEqual(labelParagraph.location, alphaParagraph.location)
    }


    func testListItemWithBoldPreservesFormatting() {
        let result = MarkdownRenderer.render("- **bold** item", config: config)

        var foundBold = false
        result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let font = value as? UIFont else { return }
            if result.string[range].contains("bold") {
                XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold))
                foundBold = true
            }
        }
        XCTAssertTrue(foundBold)
    }


    func testListFollowedByCodeBlockKeepsExternalMarginSpacer() {
        let markdown = """
        - Satellite monitoring

        ```python
        def detect():
            pass
        ```
        """
        let result = MarkdownRenderer.render(markdown, config: config)

        let monitoringRange = (result.string as NSString).range(of: "Satellite monitoring")
        XCTAssertNotEqual(monitoringRange.location, NSNotFound)

        var codeBlockLocation = NSNotFound
        result.enumerateAttribute(MarkdownAttribute.codeBlock, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard (value as? Bool) == true else { return }
            codeBlockLocation = range.location
        }
        XCTAssertNotEqual(codeBlockLocation, NSNotFound)
        XCTAssertGreaterThan(codeBlockLocation, NSMaxRange(monitoringRange))
    }
}

private extension String {
    subscript(range: NSRange) -> String {
        (self as NSString).substring(with: range)
    }
}
