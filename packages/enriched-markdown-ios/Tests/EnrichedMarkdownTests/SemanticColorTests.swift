import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class SemanticColorTests: XCTestCase {
    func testPrimaryResolvesToLabelInLightAndDark() {
        let theme = MarkdownTheme {
            Paragraph().foregroundStyle(ThemeColorSpec.SemanticColor.primary)
        }

        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)

        let lightConfig = MarkdownStyleConfiguration.resolve(layers: [theme], traitCollection: lightTraits)
        let darkConfig = MarkdownStyleConfiguration.resolve(layers: [theme], traitCollection: darkTraits)

        XCTAssertEqual(
            lightConfig.paragraph.foregroundColor,
            UIColor.label.resolvedColor(with: lightTraits)
        )
        XCTAssertEqual(
            darkConfig.paragraph.foregroundColor,
            UIColor.label.resolvedColor(with: darkTraits)
        )
        XCTAssertNotEqual(
            lightConfig.paragraph.foregroundColor,
            darkConfig.paragraph.foregroundColor
        )
    }

    func testTintResolvesForLinkThemeElement() {
        let theme = MarkdownTheme {
            Link().foregroundStyle(ThemeColorSpec.SemanticColor.tint)
        }

        let traits = UITraitCollection(userInterfaceStyle: .light)
        let config = MarkdownStyleConfiguration.resolve(layers: [theme], traitCollection: traits)

        XCTAssertEqual(
            config.link.foregroundColor,
            UIColor.tintColor.resolvedColor(with: traits)
        )
    }

    // MARK: - Member-name resolution

    func testSemanticMemberNamesResolveWithoutQualification() {
        // `.secondary` exists on both Color and SemanticColor; the Color
        // overloads are disfavored so the idiomatic SwiftUI line compiles.
        let config = MarkdownStyleConfiguration.resolve(
            layers: [MarkdownTheme {
                Paragraph().foregroundStyle(.secondary)
                Code().background(.tertiary)
                Blockquote().border(.primary, width: 2)
                Heading(1).foregroundStyle(Color(UIColor.systemRed))
            }],
            traitCollection: .current
        )
        XCTAssertEqual(config.paragraph.foregroundColor, UIColor.secondaryLabel.resolvedColor(with: .current))
        XCTAssertEqual(config.code.backgroundColor, UIColor.tertiaryLabel.resolvedColor(with: .current))
        XCTAssertEqual(config.blockquote.borderColor, UIColor.label.resolvedColor(with: .current))
        XCTAssertEqual(config.heading1.foregroundColor, UIColor.systemRed.resolvedColor(with: .current))
    }
}
