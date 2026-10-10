import SwiftUI
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
    func imageSizingConfig(_ image: BlockImage) -> MarkdownStyleConfiguration {
        MarkdownStyleConfiguration.resolve(
            layers: [.default, MarkdownTheme { image }],
            traitCollection: .current
        )
    }

    /// A text view showing `rendered` at `width`, laid out at its fitted height.
    func laidOutTextView(
        showing rendered: NSAttributedString,
        width: CGFloat = 390,
        config: MarkdownStyleConfiguration = .baseline()
    ) -> MarkdownTextView {
        let textView = MarkdownTextView()
        textView.styleConfig = config
        textView.frame = CGRect(x: 0, y: 0, width: width, height: 100)
        textView.setMarkdownAttributedText(rendered)
        textView.frame = CGRect(x: 0, y: 0, width: width, height: height(of: textView, width: width))
        textView.layoutIfNeeded()
        return textView
    }

    func height(of textView: MarkdownTextView, width: CGFloat = 200) -> CGFloat {
        textView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height
    }

    func host(
        _ representable: MarkdownTextViewRepresentable,
        size: CGSize = CGSize(width: 300, height: 600)
    ) throws -> (window: UIWindow, textView: MarkdownTextView) {
        let host = UIHostingController(rootView: representable.fixedSize(horizontal: false, vertical: true))
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        return (window, try XCTUnwrap(host.view.firstSubview(of: MarkdownTextView.self)))
    }

    func backgroundRows(of textView: MarkdownTextView, in rect: CGRect) throws -> [[UInt8]] {
        let decorator = MarkdownViewportDecorator(
            backgroundView: MarkdownDecorationView(),
            foregroundView: MarkdownDecorationView()
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: rect.size))
            decorator.draw(in: context.cgContext, textView: textView, tile: rect, pass: .background)
        }
        let cgImage = try XCTUnwrap(image.cgImage)
        let data = try XCTUnwrap(cgImage.dataProvider?.data) as Data
        return (0..<Int(rect.height)).map { row in
            Array(data[(row * cgImage.bytesPerRow)..<(row * cgImage.bytesPerRow + Int(rect.width) * 4)])
        }
    }

    func backgroundPixel(of textView: MarkdownTextView, at point: CGPoint) throws -> [UInt8] {
        let column = Int(point.x) * 4
        return Array(try backgroundRows(of: textView, in: textView.bounds)[Int(point.y)][column..<column + 4])
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

extension MarkdownTextViewRepresentable {
    static func fixture(
        attributedText: NSAttributedString,
        isBottomMarginEnabled: Bool = false,
        openURL: @escaping (URL) -> Void = { _ in }
    ) -> MarkdownTextViewRepresentable {
        MarkdownTextViewRepresentable(
            attributedText: attributedText,
            source: nil,
            isBottomMarginEnabled: isBottomMarginEnabled,
            styleConfig: .baseline(),
            openURL: openURL,
            onLinkPress: nil,
            onLinkLongPress: nil,
            selectionMenuConfig: MarkdownSelectionMenu(),
            isSelectionEnabled: true,
            selectionColor: nil,
            onTaskListItemTap: nil,
            spoilerOverlay: ParticleSpoilerOverlayProvider(),
            onSpoilerTap: nil,
            accessibilityLabels: .default
        )
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

func XCTAssertEqual(_ lhs: CGRect, _ rhs: CGRect, accuracy: CGFloat, _ message: String = "",
                    file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(lhs.minX, rhs.minX, accuracy: accuracy, message, file: file, line: line)
    XCTAssertEqual(lhs.minY, rhs.minY, accuracy: accuracy, message, file: file, line: line)
    XCTAssertEqual(lhs.width, rhs.width, accuracy: accuracy, message, file: file, line: line)
    XCTAssertEqual(lhs.height, rhs.height, accuracy: accuracy, message, file: file, line: line)
}
