import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class ThemeResolverTests: XCTestCase {
    // MARK: - SwiftUI Font resolution

    func testTextStyleFontsResolveInEverySpelling() {
        for font in [Font.title2, .system(.title2), .system(.title2, design: .default), .system(.title2, weight: nil)] {
            let resolved = ThemeResolver.resolveFont(from: font, traitCollection: .current)
            XCTAssertEqual(resolved.spec, .textStyle(.title2), "\(font)")
            XCTAssertNil(resolved.design)
            XCTAssertNil(resolved.weight)
        }
    }

    func testDesignAndWeightResolveFromSystemTextStyleFont() {
        let resolved = ThemeResolver.resolveFont(
            from: .system(.headline, design: .serif, weight: .semibold),
            traitCollection: .current
        )
        XCTAssertEqual(resolved.spec, .textStyle(.headline))
        XCTAssertEqual(resolved.design, .serif)
        XCTAssertEqual(resolved.weight, .semibold)
    }

    func testMonospacedDesignResolvesFromLegacySpelling() {
        let resolved = ThemeResolver.resolveFont(from: .system(.body, design: .monospaced), traitCollection: .current)
        XCTAssertEqual(resolved.spec, .textStyle(.body))
        XCTAssertEqual(resolved.design, .monospaced)
    }

    func testPointSizedFontFallsBackToBody() {
        // Sizes and custom names live in SwiftUI's private font box; the
        // fallback is documented and logged.
        for font in [Font.system(size: 18), .custom("Helvetica", size: 12), Font.body.weight(.bold)] {
            let resolved = ThemeResolver.resolveFont(from: font, traitCollection: .current)
            XCTAssertEqual(resolved.spec, .textStyle(.body), "\(font)")
            XCTAssertNil(resolved.weight)
        }
    }

    // MARK: - Weight, italic, and explicit forms

    private func resolvedFont(@MarkdownThemeBuilder _ content: () -> MarkdownThemeGroup) -> UIFont? {
        MarkdownStyleConfiguration.resolve(layers: [.default, MarkdownTheme(content)], traitCollection: .current).heading1.font
    }

    func testWeightAndItalicLayerOverTheLowerThemesFont() throws {
        let base = try XCTUnwrap(resolvedFont {})
        let bold = try XCTUnwrap(resolvedFont { Heading(1).fontWeight(.bold) })
        let italic = try XCTUnwrap(resolvedFont { Heading(1).italic() })
        XCTAssertEqual(bold.pointSize, base.pointSize)
        XCTAssertTrue(bold.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertTrue(italic.fontDescriptor.symbolicTraits.contains(.traitItalic))
        XCTAssertEqual(italic.pointSize, base.pointSize)
    }

    func testMonospacedDesignKeepsTheBaseWeight() throws {
        let font = try XCTUnwrap(resolvedFont { Heading(1).fontDesign(.monospaced) })
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold), "the default heading is bold")
    }

    func testCodeDefaultsToMonospacedOnlyForItsOwnFont() throws {
        let serif = MarkdownStyleConfiguration.resolve(
            layers: [
                .default,
                MarkdownTheme { CodeBlock().font(.system(.body, design: .serif)) },
                MarkdownTheme { CodeBlock().foregroundStyle(Color(UIColor.systemRed)) }
            ],
            traitCollection: .current
        ).codeBlock.font
        XCTAssertFalse(try XCTUnwrap(serif).fontDescriptor.symbolicTraits.contains(.traitMonoSpace),
                       "a recolor layer must not reset the design a lower layer chose")

        let sized = MarkdownStyleConfiguration.resolve(
            layers: [.default, MarkdownTheme { CodeBlock().font(size: 14) }],
            traitCollection: .current
        ).codeBlock.font
        XCTAssertTrue(try XCTUnwrap(sized).fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
        XCTAssertEqual(sized?.pointSize, 14)
    }

    func testItalicFalseRemovesAnInheritedItalic() throws {
        let font = try XCTUnwrap(resolvedFont { Heading(1).italic() })
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
        let upright = MarkdownStyleConfiguration.resolve(
            layers: [.default, MarkdownTheme { Heading(1).italic() }, MarkdownTheme { Heading(1).italic(false) }],
            traitCollection: .current
        ).heading1.font
        XCTAssertFalse(try XCTUnwrap(upright).fontDescriptor.symbolicTraits.contains(.traitItalic))
        XCTAssertEqual(upright?.pointSize, font.pointSize)
    }

    func testExplicitSizeAndCustomForms() throws {
        let sized = try XCTUnwrap(resolvedFont { Heading(1).font(size: 33, weight: .semibold, design: .rounded) })
        XCTAssertEqual(sized.pointSize, 33)
        let custom = try XCTUnwrap(resolvedFont { Heading(1).font(custom: "Helvetica", size: 21).italic() })
        XCTAssertEqual(custom.familyName, "Helvetica")
        XCTAssertEqual(custom.pointSize, 21)
        XCTAssertTrue(custom.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }

    func testFontModifierAppliesResolvedWeight() {
        let element = Paragraph().font(.system(.body, weight: .bold))
        XCTAssertEqual(element.fontSpec, .textStyle(.body))
        XCTAssertEqual(element.fontWeight, .bold)
    }

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
