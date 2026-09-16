import UIKit
import XCTest
@testable import EnrichedMarkdown

final class ImageBoxSizingTests: XCTestCase {
    // MARK: - Policy resolution

    func testAspectRatioOutranksEveryOtherKnob() {
        let style = ImageStyle(height: 100, maxHeight: 150, aspectRatio: 2)

        XCTAssertEqual(ImageBoxSizing(style: style), .aspectRatio(2))
    }

    func testMaxHeightOutranksFixedHeight() {
        let style = ImageStyle(height: 100, maxHeight: 150)

        XCTAssertEqual(ImageBoxSizing(style: style), .maxHeight(150))
    }

    func testHeightIsUsedWhenNoResponsiveKnobIsSet() {
        XCTAssertEqual(ImageBoxSizing(style: ImageStyle(height: 100)), .fixed(height: 100))
    }

    func testEmptyStyleFallsBackToTheDefaultHeight() {
        XCTAssertEqual(ImageBoxSizing(style: ImageStyle()), .fixed(height: ImageBoxSizing.fallbackHeight))
    }

    func testNonPositiveResponsiveKnobsCountAsUnset() {
        // A theme layer sets 0 to switch a lower layer's responsive sizing off.
        let zeroed = ImageStyle(height: 100, maxHeight: 0, aspectRatio: 0)
        XCTAssertEqual(ImageBoxSizing(style: zeroed), .fixed(height: 100))

        let negative = ImageStyle(height: 100, maxHeight: -20, aspectRatio: -1)
        XCTAssertEqual(ImageBoxSizing(style: negative), .fixed(height: 100))
    }

    func testZeroAspectRatioFallsBackToMaxHeight() {
        let style = ImageStyle(height: 100, maxHeight: 150, aspectRatio: 0)

        XCTAssertEqual(ImageBoxSizing(style: style), .maxHeight(150))
    }

    // MARK: - Box height

    func testFixedBoxIgnoresWidthAndImage() {
        let sizing = ImageBoxSizing.fixed(height: 120)

        XCTAssertEqual(sizing.boxHeight(width: 300, intrinsicSize: nil), 120)
        XCTAssertEqual(sizing.boxHeight(width: 50, intrinsicSize: CGSize(width: 10, height: 900)), 120)
    }

    func testAspectRatioBoxDerivesHeightFromWidthAlone() {
        let sizing = ImageBoxSizing.aspectRatio(2)

        XCTAssertEqual(sizing.boxHeight(width: 300, intrinsicSize: nil), 150)
        XCTAssertEqual(sizing.boxHeight(width: 300, intrinsicSize: CGSize(width: 40, height: 400)), 150)
    }

    func testAspectRatioBoxFallsBackWithoutAWidth() {
        XCTAssertEqual(
            ImageBoxSizing.aspectRatio(2).boxHeight(width: 0, intrinsicSize: nil),
            ImageBoxSizing.fallbackHeight
        )
    }

    func testMaxHeightBoxUsesTheCapUntilTheImageIsKnown() {
        XCTAssertEqual(ImageBoxSizing.maxHeight(150).boxHeight(width: 300, intrinsicSize: nil), 150)
    }

    func testMaxHeightBoxFitsAWideImageBelowTheCap() {
        let sizing = ImageBoxSizing.maxHeight(150)

        XCTAssertEqual(sizing.boxHeight(width: 300, intrinsicSize: CGSize(width: 300, height: 100)), 100)
    }

    func testMaxHeightBoxCapsATallImage() {
        let sizing = ImageBoxSizing.maxHeight(150)

        XCTAssertEqual(sizing.boxHeight(width: 300, intrinsicSize: CGSize(width: 100, height: 400)), 150)
    }

    func testMaxHeightBoxKeepsTheCapForDegenerateInputs() {
        let sizing = ImageBoxSizing.maxHeight(150)

        XCTAssertEqual(sizing.boxHeight(width: 0, intrinsicSize: CGSize(width: 300, height: 100)), 150)
        XCTAssertEqual(sizing.boxHeight(width: 300, intrinsicSize: CGSize(width: 0, height: 100)), 150)
        XCTAssertEqual(sizing.boxHeight(width: 300, intrinsicSize: CGSize(width: 300, height: 0)), 150)
    }

    // MARK: - Default resize mode

    func testResponsiveBoxesDefaultToCover() {
        XCTAssertEqual(ImageBoxSizing.maxHeight(150).defaultResizeMode, .cover)
        XCTAssertEqual(ImageBoxSizing.aspectRatio(2).defaultResizeMode, .cover)
    }

    func testFixedBoxKeepsLegacyDrawingByDefault() {
        XCTAssertNil(ImageBoxSizing.fixed(height: 200).defaultResizeMode)
    }

    func testPlaceholderHeightStandsInBeforeLayout() {
        XCTAssertEqual(ImageBoxSizing.fixed(height: 120).placeholderHeight, 120)
        XCTAssertEqual(ImageBoxSizing.maxHeight(150).placeholderHeight, 150)
        XCTAssertEqual(ImageBoxSizing.aspectRatio(2).placeholderHeight, ImageBoxSizing.fallbackHeight)
    }

    // MARK: - Drawing rects

    private let wideSource = CGSize(width: 200, height: 100)
    private let box = CGSize(width: 100, height: 100)

    func testLegacyDrawingFillsTheWidthAndCentersVertically() {
        let rect = ImageDrawing.rect(mode: nil, source: wideSource, box: box)

        XCTAssertEqual(rect, CGRect(x: 0, y: 25, width: 100, height: 50))
    }

    func testStretchFillsTheBoxExactly() {
        let rect = ImageDrawing.rect(mode: .stretch, source: wideSource, box: box)

        XCTAssertEqual(rect, CGRect(origin: .zero, size: box))
    }

    func testContainFitsInsideTheBox() {
        let rect = ImageDrawing.rect(mode: .contain, source: wideSource, box: box)

        XCTAssertEqual(rect, CGRect(x: 0, y: 25, width: 100, height: 50))
    }

    func testCoverOverflowsTheBox() {
        let rect = ImageDrawing.rect(mode: .cover, source: wideSource, box: box)

        XCTAssertEqual(rect, CGRect(x: -50, y: 0, width: 200, height: 100))
    }

    func testCenterLeavesASmallImageAtItsOwnSize() {
        let rect = ImageDrawing.rect(mode: .center, source: CGSize(width: 50, height: 50), box: box)

        XCTAssertEqual(rect, CGRect(x: 25, y: 25, width: 50, height: 50))
    }

    func testCenterScalesALargeImageDown() {
        let rect = ImageDrawing.rect(mode: .center, source: CGSize(width: 200, height: 200), box: box)

        XCTAssertEqual(rect, CGRect(origin: .zero, size: box))
    }

    func testOriginalNeverScales() {
        let rect = ImageDrawing.rect(mode: .original, source: wideSource, box: box)

        XCTAssertEqual(rect, CGRect(x: -50, y: 0, width: 200, height: 100))

        let small = ImageDrawing.rect(mode: .original, source: CGSize(width: 50, height: 50), box: box)
        XCTAssertEqual(small, CGRect(x: 25, y: 25, width: 50, height: 50))
    }

    func testDegenerateSourceFallsBackToTheBox() {
        let rect = ImageDrawing.rect(mode: .cover, source: .zero, box: box)

        XCTAssertEqual(rect, CGRect(origin: .zero, size: box))
    }
}
