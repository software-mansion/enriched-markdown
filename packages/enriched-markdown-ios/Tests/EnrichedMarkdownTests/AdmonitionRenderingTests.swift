import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class AdmonitionRenderingTests: XCTestCase {
    private var config: MarkdownStyleConfig!
    private let flags = Md4cFlags(admonitions: true)

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.baseline()
    }

    // MARK: - Helpers

    private func render(_ markdown: String, config: MarkdownStyleConfig? = nil) -> NSAttributedString {
        MarkdownRenderer.render(markdown, config: config ?? self.config, flags: flags)
    }

    private func attributes(onWord word: String, in text: NSAttributedString) -> [NSAttributedString.Key: Any] {
        let range = (text.string as NSString).range(of: word)
        XCTAssertNotEqual(range.location, NSNotFound, "'\(word)' not found in '\(text.string)'")
        guard range.location != NSNotFound else { return [:] }
        return text.attributes(at: range.location, effectiveRange: nil)
    }

    private func barColors(onWord word: String, in text: NSAttributedString) -> [UIColor]? {
        attributes(onWord: word, in: text)[MarkdownAttribute.blockquoteBarColors] as? [UIColor]
    }

    private func tint(_ type: AdmonitionType) -> UIColor {
        config.blockquote.admonitionTint(for: type)
    }

    private func paragraphStyle(onWord word: String, in text: NSAttributedString) -> NSParagraphStyle? {
        attributes(onWord: word, in: text)[.paragraphStyle] as? NSParagraphStyle
    }

    // MARK: - Rendering

    func testAdmonitionRendersTitleBeforeBody() {
        let result = render("> [!NOTE]\n> body text")

        XCTAssertTrue(result.string.hasPrefix("Note\nbody text"), result.string)
    }

    func testTitleIsBoldTintedAndMarkedAsHeader() {
        let result = render("> [!WARNING]\n> body")
        let title = attributes(onWord: "Warning", in: result)

        XCTAssertEqual(title[MarkdownAttribute.admonitionHeader] as? String, "warning")
        XCTAssertEqual(title[.foregroundColor] as? UIColor, tint(.warning))
        let font = title[.font] as? UIFont
        XCTAssertTrue(font.map(FontHelpers.hasBoldTrait) == true)
        XCTAssertEqual(MarkdownAttributeValue.intValue(from: title[MarkdownAttribute.blockquoteDepth]), 0)
        XCTAssertEqual(barColors(onWord: "Warning", in: result), [tint(.warning)])
    }

    func testBodyCarriesQuoteAttributesButNoHeaderMarker() {
        let result = render("> [!TIP]\n> body")
        let body = attributes(onWord: "body", in: result)

        XCTAssertNil(body[MarkdownAttribute.admonitionHeader])
        XCTAssertEqual(MarkdownAttributeValue.intValue(from: body[MarkdownAttribute.blockquoteDepth]), 0)
        XCTAssertEqual(barColors(onWord: "body", in: result), [tint(.tip)])
        XCTAssertEqual(body[.font] as? UIFont, config.blockquote.font)
    }

    func testTitleReservesIconColumnAndGapBeforeBody() {
        let result = render("> [!NOTE]\n> body")
        let titleStyle = paragraphStyle(onWord: "Note", in: result)
        let bodyStyle = paragraphStyle(onWord: "body", in: result)
        let titleFont = attributes(onWord: "Note", in: result)[.font] as? UIFont

        XCTAssertNotNil(titleFont)
        XCTAssertEqual(
            titleStyle?.headIndent,
            (bodyStyle?.headIndent ?? 0) + AdmonitionHeader.iconColumnWidth(for: titleFont ?? .systemFont(ofSize: 16))
        )
        XCTAssertEqual(titleStyle?.firstLineHeadIndent, titleStyle?.headIndent)
        XCTAssertEqual(titleStyle?.paragraphSpacing, AdmonitionHeader.bodyGap(for: titleFont ?? .systemFont(ofSize: 16)))
        XCTAssertEqual(bodyStyle?.paragraphSpacing, 0)
    }

    func testBackgroundIsClearUnlessThemed() {
        let unfilled = render("> [!NOTE]\n> body")
        XCTAssertEqual(
            attributes(onWord: "body", in: unfilled)[MarkdownAttribute.blockquoteBackgroundColor] as? UIColor,
            .clear
        )

        var filledConfig = config!
        filledConfig.blockquote.admonitions[.note]?.backgroundColor = .systemYellow
        let filled = render("> [!NOTE]\n> body", config: filledConfig)
        XCTAssertEqual(
            attributes(onWord: "body", in: filled)[MarkdownAttribute.blockquoteBackgroundColor] as? UIColor,
            .systemYellow
        )
        XCTAssertEqual(
            attributes(onWord: "Note", in: filled)[MarkdownAttribute.blockquoteBackgroundColor] as? UIColor,
            .systemYellow
        )
    }

    func testUnconfiguredTypeFallsBackToBorderColor() {
        var bareConfig = config!
        bareConfig.blockquote.admonitions = [:]
        bareConfig.blockquote.borderColor = .systemTeal

        let result = render("> [!CAUTION]\n> body", config: bareConfig)

        XCTAssertEqual(attributes(onWord: "Caution", in: result)[.foregroundColor] as? UIColor, .systemTeal)
    }

    func testPlainQuoteNestedInAdmonitionKeepsItsOwnLevel() {
        let result = render("> [!WARNING]\n> outer\n>\n> > inner")

        XCTAssertEqual(barColors(onWord: "outer", in: result), [tint(.warning)])
        XCTAssertEqual(barColors(onWord: "inner", in: result), [tint(.warning), config.blockquote.resolvedBorderColor])
        let inner = attributes(onWord: "inner", in: result)
        XCTAssertEqual(MarkdownAttributeValue.intValue(from: inner[MarkdownAttribute.blockquoteDepth]), 1)
        XCTAssertNil(inner[MarkdownAttribute.blockquoteBackgroundColor])
        XCTAssertGreaterThan(
            paragraphStyle(onWord: "inner", in: result)?.headIndent ?? 0,
            paragraphStyle(onWord: "outer", in: result)?.headIndent ?? 0
        )
    }

    func testAdmonitionNestedInAdmonitionGetsBothTypesAndItsOwnTitle() {
        let result = render("> [!WARNING]\n> outer\n>\n> > [!TIP]\n> > inner")

        XCTAssertTrue(result.string.contains("Warning\nouter\nTip\ninner"), result.string)
        XCTAssertEqual(barColors(onWord: "Tip", in: result), [tint(.warning), tint(.tip)])
        XCTAssertEqual(barColors(onWord: "inner", in: result), [tint(.warning), tint(.tip)])
        XCTAssertEqual(attributes(onWord: "Tip", in: result)[MarkdownAttribute.admonitionHeader] as? String, "tip")
        XCTAssertEqual(attributes(onWord: "Tip", in: result)[.foregroundColor] as? UIColor, tint(.tip))
    }

    func testPlainQuotesCarryNoBarColors() {
        let result = render("> outer\n>\n> > inner")

        XCTAssertNil(barColors(onWord: "outer", in: result))
        XCTAssertNil(barColors(onWord: "inner", in: result))
        XCTAssertNil(attributes(onWord: "outer", in: result)[MarkdownAttribute.admonitionHeader])
    }

    func testFlagOffRendersMarkerAsPlainQuoteText() {
        let result = MarkdownRenderer.render("> [!NOTE]\n> body", config: config, flags: .commonMark)

        XCTAssertTrue(result.string.contains("[!NOTE]"))
        XCTAssertNil(attributes(onWord: "body", in: result)[MarkdownAttribute.admonitionHeader])
        XCTAssertNil(barColors(onWord: "body", in: result))
    }

    func testAdmonitionInsideListItemKeepsItsOwnLinesAndColumn() {
        let result = render("- item\n\n  > [!IMPORTANT]\n  > quoted\n- next")

        XCTAssertTrue(result.string.contains("item\nImportant\nquoted\n"), result.string)
        let title = attributes(onWord: "Important", in: result)
        XCTAssertEqual(title[MarkdownAttribute.admonitionHeader] as? String, "important")
        XCTAssertNil(title[MarkdownAttribute.listDepth])
        XCTAssertNil(attributes(onWord: "quoted", in: result)[MarkdownAttribute.listDepth])
        XCTAssertNotNil(attributes(onWord: "item", in: result)[MarkdownAttribute.listDepth])

        let itemIndent = paragraphStyle(onWord: "item", in: result)?.headIndent ?? 0
        let offset = (title[MarkdownAttribute.blockquoteBarOffset] as? NSNumber).map { CGFloat($0.doubleValue) }
        XCTAssertEqual(offset, itemIndent)
        XCTAssertGreaterThan(paragraphStyle(onWord: "quoted", in: result)?.headIndent ?? 0, itemIndent)
    }

    func testPlainQuoteInsideListItemStartsOnItsOwnLine() {
        let result = render("- item\n\n  > quoted")

        XCTAssertTrue(result.string.contains("item\nquoted\n"), result.string)
        XCTAssertNil(attributes(onWord: "quoted", in: result)[MarkdownAttribute.listDepth])
        XCTAssertNotNil(attributes(onWord: "quoted", in: result)[MarkdownAttribute.blockquoteBarOffset])
    }

    func testConfiguredLineHeightAppliesToTitleAndBody() {
        var lineHeightConfig = config!
        lineHeightConfig.blockquote.lineHeight = 30
        let result = render("> [!NOTE]\n> body", config: lineHeightConfig)

        XCTAssertEqual(paragraphStyle(onWord: "Note", in: result)?.minimumLineHeight, 30)
        XCTAssertEqual(paragraphStyle(onWord: "body", in: result)?.minimumLineHeight, 30)
        XCTAssertGreaterThan(
            paragraphStyle(onWord: "Note", in: result)?.headIndent ?? 0,
            paragraphStyle(onWord: "body", in: result)?.headIndent ?? 0
        )
    }

    // MARK: - Theme

    func testDefaultThemeTintsEveryTypeWithoutFilling() {
        for type in AdmonitionType.allCases {
            XCTAssertNotNil(config.blockquote.admonitions[type]?.color, "\(type)")
            XCTAssertNil(config.blockquote.admonitions[type]?.backgroundColor, "\(type)")
        }
    }

    func testAdmonitionElementLayersOverDefaults() {
        let theme = MarkdownTheme {
            Admonition(.tip)
                .foregroundStyle(Color.red)
                .background(Color.yellow)
        }
        let resolved = MarkdownStyleConfig.resolve(layers: [.default, theme], traitCollection: .current)

        // Theme colors resolve against the trait collection, so compare resolved values.
        XCTAssertEqual(resolved.blockquote.admonitions[.tip]?.color, UIColor(Color.red).resolvedColor(with: .current))
        XCTAssertEqual(
            resolved.blockquote.admonitions[.tip]?.backgroundColor,
            UIColor(Color.yellow).resolvedColor(with: .current)
        )
        XCTAssertEqual(resolved.blockquote.admonitions[.note]?.color, config.blockquote.admonitions[.note]?.color)
    }

    func testBackgroundOnlyLayerKeepsTintFromLowerLayer() {
        let theme = MarkdownTheme {
            Admonition(.caution).background(ThemeColorSpec.SemanticColor.quaternary)
        }
        let resolved = MarkdownStyleConfig.resolve(layers: [.default, theme], traitCollection: .current)

        XCTAssertEqual(resolved.blockquote.admonitions[.caution]?.color, config.blockquote.admonitions[.caution]?.color)
        XCTAssertNotNil(resolved.blockquote.admonitions[.caution]?.backgroundColor)
    }

    // MARK: - Icons

    func testEveryTypeHasAnIconWithinTheViewBox() {
        let viewBox = CGRect(x: 0, y: 0, width: AdmonitionHeader.iconViewBox, height: AdmonitionHeader.iconViewBox)
        for type in AdmonitionType.allCases {
            guard let path = AdmonitionHeader.iconPath(for: type) else {
                XCTFail("no icon for \(type)")
                continue
            }
            XCTAssertFalse(path.isEmpty, "\(type)")
            XCTAssertTrue(viewBox.insetBy(dx: -0.01, dy: -0.01).contains(path.boundingBoxOfPath), "\(type): \(path.boundingBoxOfPath)")
        }
    }

    /// The glyphs and titles are duplicated per platform; the web file is
    /// the source of truth. Skipped outside the monorepo.
    func testIconAssetsMatchTheWebSourceOfTruth() throws {
        let webFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // EnrichedMarkdownTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // enriched-markdown-ios
            .deletingLastPathComponent() // packages
            .appendingPathComponent("react-native-enriched-markdown/src/web/renderers/admonitionIcons.ts")
        guard let rawSource = try? String(contentsOf: webFile, encoding: .utf8) else {
            throw XCTSkip("web admonitionIcons.ts not available (standalone package)")
        }
        // Prettier wraps long entries onto the next line; join key and value.
        let source = rawSource.replacingOccurrences(of: ":\\s+'", with: ": '", options: .regularExpression)

        for type in AdmonitionType.allCases {
            XCTAssertTrue(source.contains("\(type.rawValue): '\(AdmonitionHeader.iconPathData(for: type))'"), "path for \(type)")
            XCTAssertTrue(source.contains("\(type.rawValue): '\(type.title)'"), "title for \(type)")
        }
        XCTAssertTrue(source.contains("ADMONITION_ICON_VIEWBOX = \(Int(AdmonitionHeader.iconViewBox));"))
    }
}
