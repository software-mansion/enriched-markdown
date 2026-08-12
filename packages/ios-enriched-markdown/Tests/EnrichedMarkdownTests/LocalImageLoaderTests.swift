import UIKit
import XCTest
@testable import EnrichedMarkdown

final class LocalImageLoaderTests: XCTestCase {
    private func makePNGData(width: CGFloat = 8, height: CGFloat = 8) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let image = renderer.image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.pngData()!
    }

    private func writeTempPNG(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
        try makePNGData().write(to: url)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    func testDataURIRoundTrip() {
        let dataURI = "data:image/png;base64,\(makePNGData().base64EncodedString())"

        XCTAssertNotNil(LocalImageLoader.load(dataURI))
    }

    func testDataURIWithoutBase64MarkerReturnsNil() {
        XCTAssertNil(LocalImageLoader.load("data:image/png,rawpayload"))
    }

    func testFileURIRoundTrip() throws {
        let url = try writeTempPNG(named: "local-loader-test.png")

        XCTAssertNotNil(LocalImageLoader.load(url.absoluteString))
    }

    func testPercentEncodedFileURIRoundTrip() throws {
        let url = try writeTempPNG(named: "local loader spaced.png")

        let uri = url.absoluteString
        XCTAssertTrue(uri.contains("%20"))
        XCTAssertNotNil(LocalImageLoader.load(uri))
    }

    func testAbsolutePathRoundTrip() throws {
        let url = try writeTempPNG(named: "local-loader-path.png")

        XCTAssertNotNil(LocalImageLoader.load(url.path))
    }

    func testUnsupportedSchemesReturnNil() {
        XCTAssertNil(LocalImageLoader.load("content://media/external/images/1"))
        XCTAssertNil(LocalImageLoader.load("asset://images/logo.png"))
        XCTAssertNil(LocalImageLoader.load("res://drawable/logo"))
    }

    func testMissingResourceNameReturnsNil() {
        XCTAssertNil(LocalImageLoader.load("definitely-not-a-bundled-image"))
        XCTAssertNil(LocalImageLoader.load(""))
    }

    func testResourceNameNormalization() {
        XCTAssertEqual(LocalImageLoader.normalizedResourceName("My-Logo"), "my_logo")
        XCTAssertEqual(LocalImageLoader.normalizedResourceName("SRC-Assets-Logo"), "src_assets_logo")
        XCTAssertEqual(LocalImageLoader.normalizedResourceName("already_normal"), "already_normal")
    }
}
