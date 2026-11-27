import XCTest
@testable import EnrichedMarkdown

final class ImageCacheKeyTests: XCTestCase {
    private let url = "https://example.com/image.png"

    func testNoHeadersReturnsURLUnchanged() {
        XCTAssertEqual(ImageCacheKey.requestKey(url: url, headers: [:]), url)
    }

    func testHeadersAppendPipeAndHexDigest() {
        let key = ImageCacheKey.requestKey(url: url, headers: ["Authorization": "Bearer token"])

        XCTAssertTrue(key.hasPrefix(url + "|"))
        let digest = key.dropFirst(url.count + 1)
        XCTAssertEqual(digest.count, 64)
        XCTAssertTrue(digest.allSatisfy(\.isHexDigit))
    }

    func testDigestFormatIsPinned() {
        // SHA-256 of "authorization:Bearer token" — names lower-cased, pinned so
        // the key format shared across platforms never drifts.
        XCTAssertEqual(
            ImageCacheKey.requestKey(url: url, headers: ["Authorization": "Bearer token"]),
            url + "|51f4f6892958e3c3eadbf95767c862e9380e8e82742f2766664d3d76d7da919e"
        )
    }

    func testHeadersAreSortedByKeyBeforeHashing() {
        // SHA-256 of "accept:image/png\nauthorization:Bearer token" — pairs
        // joined with \n in key order regardless of dictionary order.
        let headers = ["Authorization": "Bearer token", "Accept": "image/png"]

        XCTAssertEqual(
            ImageCacheKey.requestKey(url: url, headers: headers),
            url + "|555066158678ab807ab323bf0a3f1292741be05bdfddc2ed2f45288afdf95d84"
        )
    }

    func testHeaderNamesAreCaseInsensitive() {
        XCTAssertEqual(
            ImageCacheKey.requestKey(url: url, headers: ["Authorization": "Bearer token"]),
            ImageCacheKey.requestKey(url: url, headers: ["AUTHORIZATION": "Bearer token"])
        )
    }

    func testDistinctHeadersProduceDistinctKeys() {
        let first = ImageCacheKey.requestKey(url: url, headers: ["Authorization": "Bearer a"])
        let second = ImageCacheKey.requestKey(url: url, headers: ["Authorization": "Bearer b"])

        XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(first, url)
    }
}
