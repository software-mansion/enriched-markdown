import UIKit
import XCTest
@testable import EnrichedMarkdown

/// Hands back control over when a download finishes, so a test can look at an
/// attachment both before and after the image is known.
final class DeferredImageDownloader: ImageDownloading {
    private var completions: [(UIImage?) -> Void] = []

    func download(url: String, headers: [String: String], completion: @escaping (UIImage?) -> Void) {
        completions.append(completion)
    }

    func complete(with image: UIImage?) {
        let pending = completions
        completions = []
        pending.forEach { $0(image) }
    }
}

final class LayoutObserverSpy: MarkdownAttachmentLayoutObserver {
    var callCount: Int = 0

    func attachmentDidInvalidateLayout() {
        callCount += 1
    }
}

extension XCTestCase {
    func makeImage(width: CGFloat = 4, height: CGFloat = 4) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    /// The default theme with one `BlockImage` layered over it.
    func imageSizingConfig(_ image: BlockImage) -> MarkdownStyleConfig {
        MarkdownStyleConfig.resolve(
            layers: [.default, MarkdownTheme { image }],
            traitCollection: .current
        )
    }

    /// Lets the main queue drain, where a settled layout is announced.
    func drainMainQueue(for interval: TimeInterval = 0.3) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: interval))
    }

    /// Returns once every block already on the main queue has run.
    func awaitMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
    }
}

extension UIView {
    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        for subview in subviews {
            if let match = subview as? T ?? subview.firstSubview(of: type) { return match }
        }
        return nil
    }
}
