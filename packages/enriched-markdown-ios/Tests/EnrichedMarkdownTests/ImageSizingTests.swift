import UIKit
import XCTest
@testable import EnrichedMarkdown

final class ImageSizingTests: XCTestCase {
    // MARK: - Box height

    func testFixedBoxIgnoresWidthAndImage() {
        let sizing = ImageSizing.height(120)

        XCTAssertEqual(sizing.boxHeight(width: 300, intrinsicSize: nil), 120)
        XCTAssertEqual(sizing.boxHeight(width: 50, intrinsicSize: CGSize(width: 10, height: 900)), 120)
    }

    func testAspectRatioBoxDerivesHeightFromWidthAlone() {
        let sizing = ImageSizing.aspectRatio(2)

        XCTAssertEqual(sizing.boxHeight(width: 300, intrinsicSize: nil), 150)
        XCTAssertEqual(sizing.boxHeight(width: 300, intrinsicSize: CGSize(width: 40, height: 400)), 150)
    }

    func testAspectRatioBoxFallsBackWithoutAWidth() {
        XCTAssertEqual(
            ImageSizing.aspectRatio(2).boxHeight(width: 0, intrinsicSize: nil),
            ImageSizing.fallbackHeight
        )
    }

    func testDegenerateAspectRatioFallsBack() {
        XCTAssertEqual(ImageSizing.aspectRatio(0).boxHeight(width: 300, intrinsicSize: nil), ImageSizing.fallbackHeight)
        XCTAssertEqual(ImageSizing.aspectRatio(-1).boxHeight(width: 300, intrinsicSize: nil), ImageSizing.fallbackHeight)
        XCTAssertEqual(ImageSizing.aspectRatio(.infinity).boxHeight(width: 300, intrinsicSize: nil), ImageSizing.fallbackHeight)
    }

    func testMaxHeightBoxUsesTheCapUntilTheImageIsKnown() {
        XCTAssertEqual(ImageSizing.maxHeight(150).boxHeight(width: 300, intrinsicSize: nil), 150)
    }

    func testMaxHeightBoxFitsAWideImageBelowTheCap() {
        let sizing = ImageSizing.maxHeight(150)

        XCTAssertEqual(sizing.boxHeight(width: 300, intrinsicSize: CGSize(width: 300, height: 100)), 100)
    }

    func testMaxHeightBoxCapsATallImage() {
        let sizing = ImageSizing.maxHeight(150)

        XCTAssertEqual(sizing.boxHeight(width: 300, intrinsicSize: CGSize(width: 100, height: 400)), 150)
    }

    func testMaxHeightBoxKeepsTheCapForDegenerateInputs() {
        let sizing = ImageSizing.maxHeight(150)

        XCTAssertEqual(sizing.boxHeight(width: 0, intrinsicSize: CGSize(width: 300, height: 100)), 150)
        XCTAssertEqual(sizing.boxHeight(width: 300, intrinsicSize: CGSize(width: 0, height: 100)), 150)
        XCTAssertEqual(sizing.boxHeight(width: 300, intrinsicSize: CGSize(width: 300, height: 0)), 150)
    }

    // MARK: - Default content mode

    func testResponsiveBoxesDefaultToFill() {
        XCTAssertEqual(ImageSizing.maxHeight(150).defaultContentMode, .fill)
        XCTAssertEqual(ImageSizing.aspectRatio(2).defaultContentMode, .fill)
    }

    func testFixedBoxFitsTheWidthByDefault() {
        XCTAssertEqual(ImageSizing.height(200).defaultContentMode, .fitWidth)
    }

    func testPlaceholderHeightStandsInBeforeLayout() {
        XCTAssertEqual(ImageSizing.height(120).placeholderHeight, 120)
        XCTAssertEqual(ImageSizing.maxHeight(150).placeholderHeight, 150)
        XCTAssertEqual(ImageSizing.aspectRatio(2).placeholderHeight, ImageSizing.fallbackHeight)
    }

    // MARK: - Drawing rects

    private let wideSource = CGSize(width: 200, height: 100)
    private let box = CGSize(width: 100, height: 100)

    func testFitWidthFillsTheWidthAndCentersVertically() {
        let rect = ImageDrawing.rect(mode: .fitWidth, source: wideSource, box: box)

        XCTAssertEqual(rect, CGRect(x: 0, y: 25, width: 100, height: 50))
    }

    func testFitWidthOverflowsATallImageVertically() {
        let rect = ImageDrawing.rect(mode: .fitWidth, source: CGSize(width: 100, height: 200), box: box)

        XCTAssertEqual(rect, CGRect(x: 0, y: -50, width: 100, height: 200))
    }

    func testStretchFillsTheBoxExactly() {
        let rect = ImageDrawing.rect(mode: .stretch, source: wideSource, box: box)

        XCTAssertEqual(rect, CGRect(origin: .zero, size: box))
    }

    func testFitStaysInsideTheBox() {
        let rect = ImageDrawing.rect(mode: .fit, source: CGSize(width: 100, height: 200), box: box)

        XCTAssertEqual(rect, CGRect(x: 25, y: 0, width: 50, height: 100))
    }

    func testFillOverflowsTheBox() {
        let rect = ImageDrawing.rect(mode: .fill, source: wideSource, box: box)

        XCTAssertEqual(rect, CGRect(x: -50, y: 0, width: 200, height: 100))
    }

    func testScaleDownLeavesASmallImageAtItsOwnSize() {
        let rect = ImageDrawing.rect(mode: .scaleDown, source: CGSize(width: 50, height: 50), box: box)

        XCTAssertEqual(rect, CGRect(x: 25, y: 25, width: 50, height: 50))
    }

    func testScaleDownShrinksALargeImage() {
        let rect = ImageDrawing.rect(mode: .scaleDown, source: CGSize(width: 200, height: 200), box: box)

        XCTAssertEqual(rect, CGRect(origin: .zero, size: box))
    }

    func testOriginalNeverScales() {
        let rect = ImageDrawing.rect(mode: .original, source: wideSource, box: box)

        XCTAssertEqual(rect, CGRect(x: -50, y: 0, width: 200, height: 100))

        let small = ImageDrawing.rect(mode: .original, source: CGSize(width: 50, height: 50), box: box)
        XCTAssertEqual(small, CGRect(x: 25, y: 25, width: 50, height: 50))
    }

    func testDegenerateSourceFallsBackToTheBox() {
        let rect = ImageDrawing.rect(mode: .fill, source: .zero, box: box)

        XCTAssertEqual(rect, CGRect(origin: .zero, size: box))
    }
}
