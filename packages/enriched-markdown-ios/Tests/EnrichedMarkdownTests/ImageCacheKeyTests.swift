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
        // SHA-256 of "Authorization:Bearer token" — pinned so the key format
        // shared across platforms never drifts.
        XCTAssertEqual(
            ImageCacheKey.requestKey(url: url, headers: ["Authorization": "Bearer token"]),
            url + "|06a97d81903f645b2b8286be8e5251b3ed323a07533a0609bbb87e66d7a40821"
        )
    }

    func testHeadersAreSortedByKeyBeforeHashing() {
        // SHA-256 of "Accept:image/png\nAuthorization:Bearer token" — pairs
        // joined with \n in key order regardless of dictionary order.
        let headers = ["Authorization": "Bearer token", "Accept": "image/png"]

        XCTAssertEqual(
            ImageCacheKey.requestKey(url: url, headers: headers),
            url + "|c046ce6860d64c050dd077d13a03cb285900e2fad36c5959c05aab094f838a29"
        )
    }

    func testDistinctHeadersProduceDistinctKeys() {
        let first = ImageCacheKey.requestKey(url: url, headers: ["Authorization": "Bearer a"])
        let second = ImageCacheKey.requestKey(url: url, headers: ["Authorization": "Bearer b"])

        XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(first, url)
    }
}
