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

    func testBlockImageSizingModifiersReachTheConfig() {
        let config = MarkdownStyleConfig.resolve(
            layers: [.default, MarkdownTheme {
                BlockImage()
                    .aspectRatio(16 / 9)
                    .contentMode(.fit)
            }],
            traitCollection: UITraitCollection(userInterfaceStyle: .light)
        )

        XCTAssertEqual(config.image.sizing, .aspectRatio(16 / 9))
        XCTAssertEqual(config.image.contentMode, .fit)
    }

    func testSizingModifiersOnTheElement() {
        XCTAssertEqual(BlockImage().maxHeight(150).height(100).sizing, .height(100))
        XCTAssertEqual(BlockImage().aspectRatio(CGSize(width: 16, height: 9)).sizing, .aspectRatio(16 / 9))

        let withMode = BlockImage().aspectRatio(16 / 9, contentMode: .fit)
        XCTAssertEqual(withMode.sizing, .aspectRatio(16 / 9))
        XCTAssertEqual(withMode.contentMode, .fit)
    }

    func testDefaultThemeSizesBlockImagesToAFixedHeight() {
        let config = MarkdownStyleConfig.baseline()

        XCTAssertEqual(config.image.sizing, .height(200))
        XCTAssertEqual(config.image.height, 200)
        XCTAssertNil(config.image.contentMode)
    }

    func testHigherLayerReplacesTheLowerLayerSizing() {
        let config = MarkdownStyleConfig.resolve(
            layers: [
                .default,
                MarkdownTheme { BlockImage().maxHeight(150) },
                MarkdownTheme { BlockImage().height(100) }
            ],
            traitCollection: .current
        )

        XCTAssertEqual(config.image.sizing, .height(100))
    }

    func testImageStyleHeightConvenienceReplacesTheSizing() {
        var style = ImageStyle(sizing: .maxHeight(150))

        style.height = 100

        XCTAssertEqual(style.sizing, .height(100))
        XCTAssertEqual(style.height, 100)
        XCTAssertNil(ImageStyle(sizing: .maxHeight(150)).height)
    }
}
