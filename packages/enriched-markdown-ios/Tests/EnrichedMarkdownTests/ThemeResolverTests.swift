import UIKit
import XCTest
@testable import EnrichedMarkdown

final class ThemeResolverTests: XCTestCase {
    func testCustomFontSpecResolvesRegisteredFont() {
        let spec = ThemeFontSpec.custom(name: "Helvetica", size: 16)
        let font = spec.resolve(traitCollection: .current)
        XCTAssertEqual(font.pointSize, 16)
        XCTAssertEqual(font.familyName, "Helvetica")
    }

    func testCustomFontSpecFallsBackToSystemFont() {
        let spec = ThemeFontSpec.custom(name: "NonexistentFontFace-12345", size: 18)
        let font = spec.resolve(traitCollection: .current)
        XCTAssertEqual(font.pointSize, 18)
    }

    func testCustomFontFallbackInfersBoldWeightFromName() {
        let spec = ThemeFontSpec.custom(name: "MissingMontserrat-Bold", size: 30)
        let font = spec.resolve(traitCollection: .current)
        XCTAssertEqual(font.pointSize, 30)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    func testSystemFontSpecUsesRegularWeightAtExplicitSize() {
        let spec = ThemeFontSpec.system(size: 30, weight: .regular, design: .default)
        let font = spec.resolve(traitCollection: .current)
        XCTAssertEqual(font.pointSize, 30)
        XCTAssertFalse(font.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    func testApplyFontResolvesBoldFamilyFaceForCustomSpec() {
        let font = ThemeResolver.applyFont(
            spec: .custom(name: "Helvetica", size: 20),
            weight: .bold,
            design: .monospaced,
            to: nil,
            traitCollection: .current
        )
        XCTAssertEqual(font?.pointSize, 20)
        XCTAssertEqual(font?.familyName, "Helvetica")
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
        // `.fontDesign` does not rewrite a custom PostScript face into a system design.
        XCTAssertFalse(font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) ?? true)
    }

    func testApplyFontKeepsCustomFaceWhenWeightIsRegular() {
        let font = ThemeResolver.applyFont(
            spec: .custom(name: "Helvetica", size: 20),
            weight: .regular,
            design: nil,
            to: nil,
            traitCollection: .current
        )
        XCTAssertEqual(font?.familyName, "Helvetica")
        XCTAssertFalse(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? true)
    }
}
