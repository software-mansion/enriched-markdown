import UIKit
import XCTest
@testable import EnrichedMarkdown

final class ImageDecoderTests: XCTestCase {
    private func makePNGData(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.pngData()!
    }

    func testLargeImageIsDownsampledToMaxPixelSize() {
        let data = makePNGData(width: 2000, height: 1000)

        let decoded = ImageDecoder.decodeDownsampled(data, maxPixelSize: 500, scale: 1)

        XCTAssertNotNil(decoded)
        XCTAssertLessThanOrEqual(decoded!.cgImage!.width, 500)
        XCTAssertLessThanOrEqual(decoded!.cgImage!.height, 500)
    }

    func testDownsamplingPreservesAspectRatio() {
        let data = makePNGData(width: 2000, height: 1000)

        let decoded = ImageDecoder.decodeDownsampled(data, maxPixelSize: 500, scale: 1)!

        let ratio = CGFloat(decoded.cgImage!.width) / CGFloat(decoded.cgImage!.height)
        XCTAssertEqual(ratio, 2.0, accuracy: 0.05)
    }

    func testSmallImageIsNotUpscaled() {
        let data = makePNGData(width: 40, height: 40)

        let decoded = ImageDecoder.decodeDownsampled(data, maxPixelSize: 500, scale: 1)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded!.cgImage!.width, 40)
    }

    func testResultCarriesRequestedScale() {
        let data = makePNGData(width: 100, height: 100)

        let decoded = ImageDecoder.decodeDownsampled(data, maxPixelSize: 500, scale: 2)

        XCTAssertEqual(decoded?.scale, 2)
    }

    func testInvalidDataReturnsNil() {
        XCTAssertNil(ImageDecoder.decodeDownsampled(Data()))
        XCTAssertNil(ImageDecoder.decodeDownsampled(Data("not an image".utf8)))
    }
}
