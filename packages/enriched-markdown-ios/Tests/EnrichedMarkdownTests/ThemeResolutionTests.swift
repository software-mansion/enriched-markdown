import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class ThemeResolutionTests: XCTestCase {
    func testLayeredThemesMergeDeclaredElementsOnly() {
        let traitCollection = UITraitCollection(userInterfaceStyle: .light)

        let base = MarkdownTheme {
            Paragraph()
                .fontSize(18)
                .foregroundStyle(ThemeColorSpec.SemanticColor.primary)
            Heading(1)
                .fontSize(30)
        }

        let override = MarkdownTheme {
            Heading(1)
                .fontSize(40)
                .foregroundStyle(ThemeColorSpec.SemanticColor.tint)
        }

        let config = MarkdownStyleConfig.resolve(
            layers: [base, override],
            traitCollection: traitCollection
        )

        XCTAssertEqual(config.paragraph.font?.pointSize, 18)
        XCTAssertEqual(
            config.paragraph.foregroundColor,
            UIColor.label.resolvedColor(with: traitCollection)
        )
        XCTAssertEqual(config.heading1.font?.pointSize, 40)
        XCTAssertEqual(
            config.heading1.foregroundColor,
            UIColor.tintColor.resolvedColor(with: traitCollection)
        )
    }

    func testDefaultThemeResolvesAllCommonMarkElements() {
        let config = MarkdownStyleConfig.baseline()

        XCTAssertNotNil(config.paragraph.font)
        XCTAssertNotNil(config.paragraph.foregroundColor)
        XCTAssertNotNil(config.heading1.font)
        XCTAssertNotNil(config.link.foregroundColor)
        XCTAssertTrue(config.link.underline == true)
        XCTAssertNotNil(config.codeBlock.font)
        XCTAssertNotNil(config.codeBlock.backgroundColor)
        XCTAssertNotNil(config.blockquote.borderColor)
        XCTAssertNotNil(config.list.bulletColor)
    }
}
