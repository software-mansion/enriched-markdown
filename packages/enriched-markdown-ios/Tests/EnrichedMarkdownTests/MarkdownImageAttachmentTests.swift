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

    // MARK: - Responsive sizing

    // Block images size themselves from the container width: `maxHeight` fits
    // the image below a cap, `aspectRatio` derives the height from the width.
    // A height that only settles once the image loads is the interesting case,
    // so these drive the download by hand.

    private func blockAttachment(
        _ image: BlockImage,
        downloader: ImageDownloading,
        observer: MarkdownAttachmentLayoutObserver? = nil
    ) -> MarkdownImageAttachment {
        let attachment = MarkdownImageAttachment.attachment(
            for: "https://example.com/\(#function).png",
            config: imageSizingConfig(image),
            isInline: false,
            altText: "",
            downloader: downloader
        )
        attachment.layoutObserver = observer
        return attachment
    }

    /// Runs one layout pass and answers the box height it produced.
    @discardableResult
    private func layOut(_ attachment: MarkdownImageAttachment, width: CGFloat = 300) -> CGFloat {
        attachment.attachmentBounds(
            for: nil,
            proposedLineFragment: CGRect(x: 0, y: 0, width: width, height: 20),
            glyphPosition: .zero,
            characterIndex: 0
        ).height
    }

    func testMaxHeightBoxUsesTheCapBeforeLoadingAndFitsAfter() {
        let downloader = DeferredImageDownloader()
        let attachment = blockAttachment(BlockImage().maxHeight(150), downloader: downloader)

        XCTAssertEqual(layOut(attachment), 150)

        downloader.complete(with: makeImage(width: 300, height: 100))

        XCTAssertEqual(layOut(attachment), 100)
    }

    func testFixedHeightBoxIsUnchangedByTheLoad() {
        // The default theme sizing, unchanged by this feature.
        let downloader = DeferredImageDownloader()
        let attachment = MarkdownImageAttachment.attachment(
            for: "https://example.com/\(#function).png",
            config: makeConfig(),
            isInline: false,
            altText: "",
            downloader: downloader
        )

        XCTAssertEqual(layOut(attachment), 200)

        downloader.complete(with: makeImage(width: 300, height: 100))

        XCTAssertEqual(layOut(attachment), 200)
    }

    func testInlineImagesIgnoreBlockSizing() {
        let downloader = DeferredImageDownloader()
        let attachment = MarkdownImageAttachment.attachment(
            for: "https://example.com/\(#function).png",
            config: imageSizingConfig(BlockImage().maxHeight(150)),
            isInline: true,
            altText: "",
            downloader: downloader
        )

        let bounds = attachment.attachmentBounds(
            for: nil,
            proposedLineFragment: CGRect(x: 0, y: 0, width: 300, height: 20),
            glyphPosition: .zero,
            characterIndex: 0
        )

        XCTAssertEqual(bounds.size, CGSize(width: 20, height: 20))
    }

    // MARK: - Effective content mode

    func testContentModeFollowsTheSizingUntilSet() {
        let downloader = DeferredImageDownloader()

        XCTAssertEqual(blockAttachment(BlockImage().height(200), downloader: downloader).contentMode, .fitWidth)
        XCTAssertEqual(blockAttachment(BlockImage().maxHeight(150), downloader: downloader).contentMode, .fill)
        XCTAssertEqual(blockAttachment(BlockImage().aspectRatio(2), downloader: downloader).contentMode, .fill)

        let explicit = blockAttachment(BlockImage().maxHeight(150).contentMode(.fit), downloader: downloader)
        XCTAssertEqual(explicit.contentMode, .fit)
    }

    func testInlineImagesAlwaysFillTheirSquare() {
        let downloader = DeferredImageDownloader()
        let attachment = MarkdownImageAttachment.attachment(
            for: "https://example.com/\(#function).png",
            config: imageSizingConfig(BlockImage().contentMode(.fit)),
            isInline: true,
            altText: "",
            downloader: downloader
        )

        XCTAssertEqual(attachment.contentMode, .stretch)
    }

    func testLoadArrivingOffTheMainThreadIsAppliedOnMain() {
        let downloader = DeferredImageDownloader()
        let attachment = blockAttachment(BlockImage().maxHeight(150), downloader: downloader)

        let delivered = expectation(description: "delivered off main")
        DispatchQueue.global().async {
            downloader.complete(with: self.makeImage(width: 300, height: 100))
            delivered.fulfill()
        }
        wait(for: [delivered], timeout: 1)
        awaitMainQueue()

        XCTAssertEqual(layOut(attachment), 100)
    }

    // MARK: - Re-measure notifications

    func testSettledBoxAsksTheHostToMeasureAgain() {
        let downloader = DeferredImageDownloader()
        let observer = LayoutObserverSpy()
        let attachment = blockAttachment(BlockImage().maxHeight(150), downloader: downloader, observer: observer)
        layOut(attachment)

        downloader.complete(with: makeImage(width: 300, height: 100))
        drainMainQueue()

        XCTAssertEqual(observer.callCount, 1)
    }

    func testBoxThatKeepsItsHeightDoesNotNotify() {
        // The image is taller than the cap, so the pre-load height was right.
        let downloader = DeferredImageDownloader()
        let observer = LayoutObserverSpy()
        let attachment = blockAttachment(BlockImage().maxHeight(150), downloader: downloader, observer: observer)
        layOut(attachment)

        downloader.complete(with: makeImage(width: 100, height: 400))
        drainMainQueue()

        XCTAssertEqual(observer.callCount, 0)
    }

    func testFixedAndAspectRatioBoxesNeverNotify() {
        let fixedDownloader = DeferredImageDownloader()
        let fixedObserver = LayoutObserverSpy()
        let fixed = blockAttachment(BlockImage().height(200), downloader: fixedDownloader, observer: fixedObserver)
        layOut(fixed)

        let ratioDownloader = DeferredImageDownloader()
        let ratioObserver = LayoutObserverSpy()
        let ratio = blockAttachment(BlockImage().aspectRatio(2), downloader: ratioDownloader, observer: ratioObserver)
        layOut(ratio)

        fixedDownloader.complete(with: makeImage(width: 300, height: 100))
        ratioDownloader.complete(with: makeImage(width: 300, height: 100))
        drainMainQueue()

        XCTAssertEqual(fixedObserver.callCount, 0)
        XCTAssertEqual(ratioObserver.callCount, 0)
    }
}
