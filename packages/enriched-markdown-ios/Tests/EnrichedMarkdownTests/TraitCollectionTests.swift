import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class TraitCollectionTests: XCTestCase {
    func testResolveProducesDifferentColorsAcrossColorSchemes() {
        let lightTraits = ThemeResolver.traitCollection(colorScheme: .light, dynamicTypeSize: .large)
        let darkTraits = ThemeResolver.traitCollection(colorScheme: .dark, dynamicTypeSize: .large)

        let lightConfig = MarkdownStyleConfiguration.resolve(layers: [.default], traitCollection: lightTraits)
        let darkConfig = MarkdownStyleConfiguration.resolve(layers: [.default], traitCollection: darkTraits)

        XCTAssertNotEqual(
            lightConfig.paragraph.foregroundColor,
            darkConfig.paragraph.foregroundColor
        )
    }

    func testTraitCollectionMapsDynamicTypeSize() {
        let smallTraits = ThemeResolver.traitCollection(colorScheme: .light, dynamicTypeSize: .small)
        let largeTraits = ThemeResolver.traitCollection(colorScheme: .light, dynamicTypeSize: .xxxLarge)

        let smallConfig = MarkdownStyleConfiguration.resolve(layers: [.default], traitCollection: smallTraits)
        let largeConfig = MarkdownStyleConfiguration.resolve(layers: [.default], traitCollection: largeTraits)

        let smallSize = smallConfig.paragraph.font?.pointSize ?? 0
        let largeSize = largeConfig.paragraph.font?.pointSize ?? 0
        XCTAssertGreaterThan(largeSize, smallSize)
    }
}
