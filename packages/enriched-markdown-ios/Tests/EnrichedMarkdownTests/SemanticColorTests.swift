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

        let lightConfig = MarkdownStyleConfig.resolve(layers: [theme], traitCollection: lightTraits)
        let darkConfig = MarkdownStyleConfig.resolve(layers: [theme], traitCollection: darkTraits)

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
        let config = MarkdownStyleConfig.resolve(layers: [theme], traitCollection: traits)

        XCTAssertEqual(
            config.link.foregroundColor,
            UIColor.tintColor.resolvedColor(with: traits)
        )
    }
}
