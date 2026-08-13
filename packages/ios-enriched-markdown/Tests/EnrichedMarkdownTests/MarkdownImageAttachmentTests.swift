import UIKit
import XCTest
@testable import EnrichedMarkdown

private final class MockImageDownloader: ImageDownloading {
    var requestedURLs: [String] = []
    var requestedHeaders: [[String: String]] = []
    var stubbedImage: UIImage?

    func download(url: String, headers: [String: String], completion: @escaping (UIImage?) -> Void) {
        requestedURLs.append(url)
        requestedHeaders.append(headers)
        completion(stubbedImage)
    }
}

final class MarkdownImageAttachmentTests: XCTestCase {
    private func makeConfig() -> MarkdownStyleConfig {
        MarkdownStyleConfig.resolve(layers: [.default], traitCollection: .current)
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    func testAttachmentRequestsImageFromInjectedDownloader() {
        let downloader = MockImageDownloader()
        let url = "https://example.com/\(#function).png"

        _ = MarkdownImageAttachment.attachment(
            for: url,
            config: makeConfig(),
            isInline: false,
            altText: "",
            downloader: downloader
        )

        XCTAssertEqual(downloader.requestedURLs, [url])
    }

    func testInlineAttachmentUsesLoadedImageForDisplay() {
        let downloader = MockImageDownloader()
        downloader.stubbedImage = makeImage()
        let url = "https://example.com/\(#function).png"

        let attachment = MarkdownImageAttachment.attachment(
            for: url,
            config: makeConfig(),
            isInline: true,
            altText: "",
            downloader: downloader
        )

        let expectation = expectation(description: "image processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        let displayed = attachment.image(
            forBounds: CGRect(x: 0, y: 0, width: 20, height: 20),
            textContainer: nil,
            characterIndex: 0
        )
        XCTAssertNotNil(displayed)
    }

    func testAttachmentExposesAltTextAsAccessibilityLabel() {
        let downloader = MockImageDownloader()
        let url = "https://example.com/\(#function).png"

        let attachment = MarkdownImageAttachment.attachment(
            for: url,
            config: makeConfig(),
            isInline: false,
            altText: "A red square",
            downloader: downloader
        )

        XCTAssertEqual(attachment.accessibilityLabel, "A red square")
    }

    func testRequestHeadersReachDownloader() {
        let downloader = MockImageDownloader()
        let url = "https://example.com/\(#function).png"
        let headers = ["Authorization": "Bearer token"]

        _ = MarkdownImageAttachment.attachment(
            for: url,
            config: makeConfig(),
            isInline: false,
            altText: "",
            requestHeaders: headers,
            downloader: downloader
        )

        XCTAssertEqual(downloader.requestedHeaders, [headers])
    }

    func testEveryCallYieldsFreshAttachmentInstance() {
        // Attachments carry per-position layout state, so instances must
        // never be shared — even for identical URL + headers.
        let downloader = MockImageDownloader()
        downloader.stubbedImage = makeImage()
        let url = "https://example.com/\(#function).png"

        func attachment() -> MarkdownImageAttachment {
            MarkdownImageAttachment.attachment(
                for: url,
                config: makeConfig(),
                isInline: true,
                altText: "",
                requestHeaders: ["Authorization": "Bearer a"],
                downloader: downloader
            )
        }

        XCTAssertFalse(attachment() === attachment())
    }

    func testDuplicateImageURLsRenderAsIndependentAttachments() {
        // Regression: with a shared instance, only the first occurrence of a
        // repeated image URL would draw and refresh.
        let url = "https://example.invalid/repeated.png"
        let result = MarkdownRenderer.render(
            "![a](\(url))\n\n![a](\(url))",
            config: makeConfig()
        )

        var attachments: [MarkdownImageAttachment] = []
        result.enumerateAttribute(.attachment, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if let attachment = value as? MarkdownImageAttachment {
                attachments.append(attachment)
            }
        }

        XCTAssertEqual(attachments.count, 2)
        XCTAssertFalse(attachments[0] === attachments[1])
    }

    func testEmptyURLDoesNotHitDownloader() {
        let downloader = MockImageDownloader()

        _ = MarkdownImageAttachment.attachment(
            for: "",
            config: makeConfig(),
            isInline: false,
            altText: "",
            downloader: downloader
        )

        XCTAssertTrue(downloader.requestedURLs.isEmpty)
    }
}
