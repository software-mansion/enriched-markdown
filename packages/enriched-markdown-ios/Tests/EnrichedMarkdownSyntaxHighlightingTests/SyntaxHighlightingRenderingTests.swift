import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownSyntaxHighlighting

final class SyntaxHighlightingRenderingTests: XCTestCase {
    private let python = "```python\ndef f():\n    return 1 + 2  # note\n```"

    private func withoutForegroundColor(_ rendered: NSAttributedString) -> NSAttributedString {
        let copy = NSMutableAttributedString(attributedString: rendered)
        copy.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: copy.length))
        return copy
    }

    // MARK: - Rendering

    func testTokensTakeTheirThemeColors() {
        let config = highlightingConfig()
        let colors = config.syntaxHighlight.colors
        let rendered = MarkdownRenderer.renderSyntaxHighlighted(python, config: config)

        XCTAssertEqual(rendered.foregroundColor(of: "def"), colors[.keyword])
        XCTAssertEqual(rendered.foregroundColor(of: "return"), colors[.keyword])
        XCTAssertEqual(rendered.foregroundColor(of: "f("), colors[.function])
        XCTAssertEqual(rendered.foregroundColor(of: "1"), colors[.number])
        XCTAssertEqual(rendered.foregroundColor(of: "# note"), colors[.comment])
    }

    func testUncoloredTokenTypesKeepTheCodeBlockColor() {
        let config = highlightingConfig()
        let rendered = MarkdownRenderer.renderSyntaxHighlighted(python, config: config)

        XCTAssertTrue(SyntaxHighlighter.tokens(in: "1 + 2", language: "python").contains { $0.type == .operator })
        XCTAssertNil(config.syntaxHighlight.colors[.operator])
        XCTAssertEqual(rendered.foregroundColor(of: "+"), config.codeBlock.foregroundColor)
    }

    func testOnlyTheForegroundColorChanges() {
        let config = highlightingConfig()
        let plain = MarkdownRenderer.render(python, config: config)
        let highlighted = MarkdownRenderer.renderSyntaxHighlighted(python, config: config)

        XCTAssertNotEqual(highlighted, plain)
        XCTAssertEqual(withoutForegroundColor(highlighted), withoutForegroundColor(plain))
    }

    func testBaseRenderIgnoresThePalette() {
        let config = highlightingConfig()
        let rendered = MarkdownRenderer.render(python, config: config)

        XCTAssertEqual(rendered.foregroundColor(of: "def"), config.codeBlock.foregroundColor)
    }

    func testBlockWithoutACoveredLanguageStaysPlain() {
        let config = highlightingConfig()

        for fence in ["```", "```klingon"] {
            let markdown = "\(fence)\ndef f():\n    return 1\n```"
            XCTAssertEqual(
                MarkdownRenderer.renderSyntaxHighlighted(markdown, config: config),
                MarkdownRenderer.render(markdown, config: config),
                "fence '\(fence)'"
            )
        }
    }

    func testInfoStringTakesItsFirstWord() {
        let config = highlightingConfig()
        let rendered = MarkdownRenderer.renderSyntaxHighlighted(
            "~~~python title=\"greet.py\"\ndef f():\n    return 1\n~~~",
            config: config
        )

        XCTAssertEqual(rendered.foregroundColor(of: "def"), config.syntaxHighlight.colors[.keyword])
    }

    func testEachBlockUsesItsOwnLanguage() {
        let config = highlightingConfig()
        let colors = config.syntaxHighlight.colors
        let rendered = MarkdownRenderer.renderSyntaxHighlighted(
            "\(python)\n\nBetween.\n\n```json\n{\"enabled\": true}\n```",
            config: config
        )

        XCTAssertEqual(rendered.foregroundColor(of: "def"), colors[.keyword])
        XCTAssertEqual(rendered.foregroundColor(of: "\"enabled\""), colors[.string])
        XCTAssertEqual(rendered.foregroundColor(of: "true"), colors[.constant])
        XCTAssertEqual(rendered.foregroundColor(of: "Between"), config.paragraph.foregroundColor)
    }

    func testBlocksNestedInListsAndQuotesHighlight() {
        let config = highlightingConfig()
        let keyword = config.syntaxHighlight.colors[.keyword]

        let inList = MarkdownRenderer.renderSyntaxHighlighted(
            "- item\n\n  ```python\n  def f():\n      return 1\n  ```",
            config: config
        )
        let inQuote = MarkdownRenderer.renderSyntaxHighlighted(
            "> ```python\n> def f():\n>     return 1\n> ```",
            config: config
        )

        XCTAssertEqual(inList.foregroundColor(of: "def"), keyword)
        XCTAssertEqual(inQuote.foregroundColor(of: "def"), keyword)
    }

    func testNonASCIICodeKeepsTokenPositions() {
        let config = highlightingConfig()
        let colors = config.syntaxHighlight.colors
        let rendered = MarkdownRenderer.renderSyntaxHighlighted("```python\nx = \"🎉é\"  # 🎉\nimport os\n```", config: config)

        XCTAssertEqual(rendered.foregroundColor(of: "\"🎉é\""), colors[.string])
        XCTAssertEqual(rendered.foregroundColor(of: "  #"), config.codeBlock.foregroundColor)
        XCTAssertEqual(rendered.foregroundColor(of: "# 🎉"), colors[.comment])
        XCTAssertEqual(rendered.foregroundColor(of: "import"), colors[.keyword])
    }

    func testThemeColorsReachTheRenderedBlock() {
        let config = highlightingConfig {
            SyntaxToken(.keyword).foregroundStyle(Color(red: 1, green: 0, blue: 1))
            SyntaxToken(.operator).foregroundStyle(.secondary)
        }
        let rendered = MarkdownRenderer.renderSyntaxHighlighted(python, config: config)

        XCTAssertEqual(hex(rendered.foregroundColor(of: "def")), 0xFF00FF)
        XCTAssertEqual(rendered.foregroundColor(of: "+"), UIColor.secondaryLabel.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)))
        XCTAssertEqual(rendered.foregroundColor(of: "1"), config.syntaxHighlight.colors[.number], "the default palette still applies")
    }

    // MARK: - Theme

    func testSyntaxTokenAppliesToConfig() {
        var config = MarkdownStyleConfiguration()
        XCTAssertTrue(config.syntaxHighlight.colors.isEmpty)

        SyntaxToken(.keyword).apply(to: &config, traitCollection: .current)
        XCTAssertTrue(config.syntaxHighlight.colors.isEmpty, "an element without a color sets nothing")

        SyntaxToken(.keyword).foregroundStyle(Color(red: 1, green: 0, blue: 0)).apply(to: &config, traitCollection: .current)
        SyntaxToken(.comment).foregroundStyle(.secondary).apply(to: &config, traitCollection: .current)
        SyntaxToken(.string).foregroundStyle(.purple).apply(to: &config, traitCollection: .current)

        XCTAssertEqual(hex(config.syntaxHighlight.colors[.keyword]), 0xFF0000)
        XCTAssertEqual(
            config.syntaxHighlight.colors[.comment],
            UIColor.secondaryLabel.resolvedColor(with: .current)
        )
        XCTAssertNotNil(config.syntaxHighlight.colors[.string])
        XCTAssertEqual(config.syntaxHighlight.colors.count, 3)
    }

    func testDefaultPaletteFollowsTheColorScheme() {
        let light = highlightingConfig(style: .light).syntaxHighlight.colors
        let dark = highlightingConfig(style: .dark).syntaxHighlight.colors

        XCTAssertEqual(hex(light[.keyword]), 0xCF222E)
        XCTAssertEqual(hex(light[.string]), 0x0A3069)
        XCTAssertEqual(hex(light[.comment]), 0x6E7781)

        XCTAssertEqual(hex(dark[.keyword]), 0xFF7B72)
        XCTAssertEqual(hex(dark[.string]), 0xA5D6FF)
        XCTAssertEqual(hex(dark[.number]), 0x79C0FF)
        XCTAssertEqual(hex(dark[.constant]), 0x79C0FF)
        XCTAssertEqual(hex(dark[.comment]), 0x8B949E)
        XCTAssertEqual(hex(dark[.function]), 0xD2A8FF)
        XCTAssertEqual(hex(dark[.type]), 0xFFA657)
        XCTAssertEqual(hex(dark[.property]), 0x79C0FF)
        XCTAssertEqual(hex(dark[.tag]), 0x7EE787)
        XCTAssertEqual(hex(dark[.attribute]), 0x79C0FF)
    }

    func testDefaultPaletteLeavesInheritingTypesUnset() {
        let colors = highlightingConfig().syntaxHighlight.colors
        let inheriting: Set<SyntaxTokenType> = [.operator, .punctuation, .variable, .embedded]

        for type in SyntaxTokenType.allCases {
            XCTAssertEqual(colors[type] == nil, inheriting.contains(type), "\(type)")
        }
    }

    func testLaterLayersOverrideSingleTypes() {
        let base = highlightingConfig()
        let themed = highlightingConfig { SyntaxToken(.keyword).foregroundStyle(Color(red: 0, green: 0, blue: 1)) }

        XCTAssertEqual(hex(themed.syntaxHighlight.colors[.keyword]), 0x0000FF)
        XCTAssertEqual(themed.syntaxHighlight.colors[.string], base.syntaxHighlight.colors[.string])
        XCTAssertEqual(themed.syntaxHighlight.colors.count, base.syntaxHighlight.colors.count)
    }

    func testTokenTypesMatchTheSharedSeam() {
        XCTAssertEqual(SyntaxTokenType.allCases.map(\.rawValue), Array(0...13))
        XCTAssertEqual(SyntaxTokenType.keyword.rawValue, 0)
        XCTAssertEqual(SyntaxTokenType.comment.rawValue, 6)
        XCTAssertEqual(SyntaxTokenType.embedded.rawValue, 13)
    }
}
