import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class TraitCollectionTests: XCTestCase {
    func testResolveProducesDifferentColorsAcrossColorSchemes() {
        let lightTraits = ThemeResolver.traitCollection(colorScheme: .light, dynamicTypeSize: .large)
        let darkTraits = ThemeResolver.traitCollection(colorScheme: .dark, dynamicTypeSize: .large)

        let lightConfig = MarkdownStyleConfig.resolve(layers: [.default], traitCollection: lightTraits)
        let darkConfig = MarkdownStyleConfig.resolve(layers: [.default], traitCollection: darkTraits)

        XCTAssertNotEqual(
            lightConfig.paragraph.foregroundColor,
            darkConfig.paragraph.foregroundColor
        )
    }

    func testTraitCollectionMapsDynamicTypeSize() {
        let smallTraits = ThemeResolver.traitCollection(colorScheme: .light, dynamicTypeSize: .small)
        let largeTraits = ThemeResolver.traitCollection(colorScheme: .light, dynamicTypeSize: .xxxLarge)

        let smallConfig = MarkdownStyleConfig.resolve(layers: [.default], traitCollection: smallTraits)
        let largeConfig = MarkdownStyleConfig.resolve(layers: [.default], traitCollection: largeTraits)

        let smallSize = smallConfig.paragraph.font?.pointSize ?? 0
        let largeSize = largeConfig.paragraph.font?.pointSize ?? 0
        XCTAssertGreaterThan(largeSize, smallSize)
    }
}
