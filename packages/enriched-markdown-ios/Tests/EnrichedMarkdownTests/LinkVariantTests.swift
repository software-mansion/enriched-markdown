import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class LinkVariantTests: XCTestCase {
    private let markdown = "Ask [alice](user://alice) or [bob](user://bob), or read the [docs](https://swmansion.com)."
    private let traitCollection = UITraitCollection(userInterfaceStyle: .light)
    private var config: MarkdownStyleConfiguration!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfiguration.baseline(traitCollection: traitCollection)
    }

    // MARK: - Theme resolution

    func testVariantElementLandsNextToTheBaseLink() {
        let resolved = MarkdownStyleConfiguration.resolve(
            layers: [.default, MarkdownTheme {
                Link(matching: "^user:")
                    .foregroundStyle(ThemeColorSpec.SemanticColor.secondary)
                    .background(ThemeColorSpec.SemanticColor.quaternary)
                    .underline(false)
            }],
            traitCollection: traitCollection
        )

        XCTAssertEqual(resolved.linkVariants, [LinkVariantStyle(pattern: "^user:", style: ElementStyle(
            foregroundColor: UIColor.secondaryLabel.resolvedColor(with: traitCollection),
            backgroundColor: UIColor.quaternaryLabel.resolvedColor(with: traitCollection),
            underline: false
        ))])
        XCTAssertEqual(resolved.link, config.link)
    }

    func testLayersMergeVariantsWithTheSamePattern() {
        let resolved = MarkdownStyleConfiguration.resolve(
            layers: [
                MarkdownTheme { Link(matching: "^user:").foregroundStyle(ThemeColorSpec.SemanticColor.tint) },
                MarkdownTheme { Link(matching: "^user:").underline(false) },
                MarkdownTheme { Link(matching: "^channel:").underline(false) }
            ],
            traitCollection: traitCollection
        )

        XCTAssertEqual(resolved.linkVariants, [
            LinkVariantStyle(pattern: "^user:", style: ElementStyle(
                foregroundColor: UIColor.tintColor.resolvedColor(with: traitCollection),
                underline: false
            )),
            LinkVariantStyle(pattern: "^channel:", style: ElementStyle(underline: false))
        ])
    }

    func testLinkBackgroundModifierReachesTheConfiguration() {
        let resolved = MarkdownStyleConfiguration.resolve(
            layers: [MarkdownTheme { Link().background(ThemeColorSpec.SemanticColor.quaternary) }],
            traitCollection: traitCollection
        )

        XCTAssertEqual(resolved.link.backgroundColor, UIColor.quaternaryLabel.resolvedColor(with: traitCollection))
        XCTAssertTrue(resolved.linkVariants.isEmpty)
    }

    // MARK: - Rendering

    func testMatchingLinksTakeTheVariantStyle() {
        config.linkVariants = [LinkVariantStyle(
            pattern: "^user:",
            style: ElementStyle(foregroundColor: .systemRed, backgroundColor: .systemYellow, underline: false)
        )]
        let result = MarkdownRenderer.render(markdown, config: config)

        XCTAssertEqual(foregroundColor(onWord: "alice", in: result), .systemRed)
        XCTAssertEqual(backgroundColor(onWord: "alice", in: result), .systemYellow)
        XCTAssertEqual(underlineStyle(onWord: "alice", in: result), 0)
        XCTAssertEqual(foregroundColor(onWord: "docs", in: result), config.link.foregroundColor)
        XCTAssertNil(backgroundColor(onWord: "docs", in: result))
        XCTAssertEqual(underlineStyle(onWord: "docs", in: result), NSUnderlineStyle.single.rawValue)
        XCTAssertEqual(attribute(.link, onWord: "alice", in: result) as? URL, URL(string: "user://alice"))
    }

    func testUnsetVariantPropertiesFallBackToTheBaseLink() {
        config.link.underline = false
        config.linkVariants = [LinkVariantStyle(pattern: "^user:", style: ElementStyle(backgroundColor: .systemYellow))]
        let result = MarkdownRenderer.render(markdown, config: config)

        XCTAssertEqual(foregroundColor(onWord: "alice", in: result), config.link.foregroundColor)
        XCTAssertEqual(backgroundColor(onWord: "alice", in: result), .systemYellow)
        XCTAssertEqual(underlineStyle(onWord: "alice", in: result), 0)
    }

    func testLongestMatchingPatternWinsInEitherOrder() {
        let broad = LinkVariantStyle(pattern: "^user:", style: ElementStyle(foregroundColor: .systemRed))
        let narrow = LinkVariantStyle(pattern: "^user://alice", style: ElementStyle(foregroundColor: .systemBlue))

        for variants in [[broad, narrow], [narrow, broad]] {
            config.linkVariants = variants
            let result = MarkdownRenderer.render(markdown, config: config)
            XCTAssertEqual(foregroundColor(onWord: "alice", in: result), .systemBlue, "variants: \(variants.map(\.pattern))")
            XCTAssertEqual(foregroundColor(onWord: "bob", in: result), .systemRed, "variants: \(variants.map(\.pattern))")
        }
    }

    func testEqualLengthPatternsFallToTheFirstDeclared() {
        config.linkVariants = [
            LinkVariantStyle(pattern: "alice", style: ElementStyle(foregroundColor: .systemRed)),
            LinkVariantStyle(pattern: "user:", style: ElementStyle(foregroundColor: .systemBlue))
        ]
        let result = MarkdownRenderer.render(markdown, config: config)

        XCTAssertEqual(foregroundColor(onWord: "alice", in: result), .systemRed)
        XCTAssertEqual(foregroundColor(onWord: "bob", in: result), .systemBlue)
    }

    func testInvalidPatternIsIgnored() {
        config.linkVariants = [
            LinkVariantStyle(pattern: "(user", style: ElementStyle(foregroundColor: .systemRed)),
            LinkVariantStyle(pattern: "^user:", style: ElementStyle(foregroundColor: .systemBlue))
        ]
        let result = MarkdownRenderer.render(markdown, config: config)

        XCTAssertEqual(foregroundColor(onWord: "alice", in: result), .systemBlue)
    }

    func testBaseLinkBackgroundReachesEveryLink() {
        config.link.backgroundColor = .systemYellow
        let result = MarkdownRenderer.render(markdown, config: config)

        XCTAssertEqual(backgroundColor(onWord: "alice", in: result), .systemYellow)
        XCTAssertEqual(backgroundColor(onWord: "docs", in: result), .systemYellow)
    }

    func testInlineCodeInsideAVariantLinkKeepsItsOwnBackground() {
        config.code.backgroundColor = .systemGray
        config.linkVariants = [LinkVariantStyle(pattern: "^user:", style: ElementStyle(backgroundColor: .systemYellow))]
        let result = MarkdownRenderer.render("[`alice` profile](user://alice)", config: config)

        XCTAssertEqual(backgroundColor(onWord: "alice", in: result), .systemGray)
        XCTAssertEqual(backgroundColor(onWord: "profile", in: result), .systemYellow)
    }

    func testEmphasisKeepsTheVariantColorInsideAndAround() {
        config.emphasis.foregroundColor = .systemGreen
        config.linkVariants = [LinkVariantStyle(pattern: "^user:", style: ElementStyle(foregroundColor: .systemRed))]

        let inside = MarkdownRenderer.render("[*alice*](user://alice)", config: config)
        XCTAssertEqual(foregroundColor(onWord: "alice", in: inside), .systemRed)

        let around = MarkdownRenderer.render("*[alice](user://alice)*", config: config)
        XCTAssertEqual(foregroundColor(onWord: "alice", in: around), .systemRed)
    }

    // MARK: - Copy as HTML

    func testCopiedHTMLCarriesTheVariantStyle() {
        config.linkVariants = [LinkVariantStyle(pattern: "^user:", style: ElementStyle(
            foregroundColor: UIColor(red: 1, green: 0, blue: 0, alpha: 1),
            backgroundColor: UIColor(red: 0, green: 0, blue: 1, alpha: 1),
            underline: false
        ))]
        let rendered = MarkdownRenderer.render(markdown, config: config)
        let html = MarkdownHTMLGenerator.generateHTML(
            from: rendered,
            in: NSRange(location: 0, length: rendered.length),
            config: config
        )

        XCTAssertTrue(html.contains(
            "<a href=\"user://alice\" style=\"color: #FF0000; text-decoration: none; background-color: #0000FF;\">alice</a>"
        ), html)
        XCTAssertTrue(html.contains("text-decoration: underline;\">docs</a>"), html)
    }

    // MARK: - Helpers

    private func attribute(_ key: NSAttributedString.Key, onWord word: String, in attributed: NSAttributedString) -> Any? {
        let range = (attributed.string as NSString).range(of: word)
        XCTAssertNotEqual(range.location, NSNotFound, "expected '\(word)' in \(attributed.string)")
        return attributed.attribute(key, at: range.location, effectiveRange: nil)
    }

    private func foregroundColor(onWord word: String, in attributed: NSAttributedString) -> UIColor? {
        attribute(.foregroundColor, onWord: word, in: attributed) as? UIColor
    }

    private func backgroundColor(onWord word: String, in attributed: NSAttributedString) -> UIColor? {
        attribute(.backgroundColor, onWord: word, in: attributed) as? UIColor
    }

    private func underlineStyle(onWord word: String, in attributed: NSAttributedString) -> Int? {
        MarkdownAttributeValue.intValue(from: attribute(.underlineStyle, onWord: word, in: attributed))
    }
}
