import CoreGraphics
import XCTest
@testable import EnrichedMarkdown

final class SVGPathParserTests: XCTestCase {
    private func bounds(_ data: String) -> CGRect? {
        SVGPathParser.path(from: data)?.boundingBoxOfPath
    }

    func testEmptyInputYieldsNoPath() {
        XCTAssertNil(SVGPathParser.path(from: ""))
    }

    func testAbsoluteLinesAndClose() {
        XCTAssertEqual(bounds("M0 0L10 0 10 10Z"), CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    func testRelativeHorizontalAndVerticalLines() {
        XCTAssertEqual(bounds("m1 1h2v2z"), CGRect(x: 1, y: 1, width: 2, height: 2))
    }

    func testNumbersRunTogetherWithSignsAndDots() {
        // "16 0Zm8-6.5" style: a sign or dot starts the next number.
        XCTAssertEqual(bounds("M0 0h16v.5h-16Z"), CGRect(x: 0, y: 0, width: 16, height: 0.5))
    }

    func testCubicAndSmoothCurvesAdvanceTheCurrentPoint() {
        let box = bounds("M0 0C0 5 5 5 5 0s5-5 5 0")
        XCTAssertEqual(box?.minX, 0)
        XCTAssertEqual(box?.maxX, 10)
    }

    func testArcSpansItsEndpoints() {
        guard let box = bounds("M0 0A5 5 0 0 1 10 0") else {
            return XCTFail("no path")
        }
        XCTAssertEqual(box.minX, 0, accuracy: 0.01)
        XCTAssertEqual(box.maxX, 10, accuracy: 0.01)
        XCTAssertEqual(box.height, 5, accuracy: 0.1)
    }

    func testZeroRadiusArcBecomesALine() {
        XCTAssertEqual(bounds("M0 0A0 0 0 0 1 10 10"), CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    func testMalformedCommandKeepsWhatWasParsed() {
        XCTAssertEqual(bounds("M0 0L10 0L"), CGRect(x: 0, y: 0, width: 10, height: 0))
    }

    func testDataBeforeAnyCommandIsIgnored() {
        XCTAssertTrue(SVGPathParser.path(from: "1 2 3")?.isEmpty == true)
    }
}
