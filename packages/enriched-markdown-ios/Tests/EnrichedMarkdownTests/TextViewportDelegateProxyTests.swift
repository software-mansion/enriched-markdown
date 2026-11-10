import UIKit
import XCTest
@testable import EnrichedMarkdown

private final class RecordingDelegate: UIView, NSTextViewportLayoutControllerDelegate {
    var viewport = CGRect(x: 0, y: 0, width: 100, height: 1000)
    var layoutRequests = 0
    var extraMessages = 0

    func viewportBounds(for textViewportLayoutController: NSTextViewportLayoutController) -> CGRect {
        viewport
    }

    func textViewportLayoutController(
        _ textViewportLayoutController: NSTextViewportLayoutController,
        configureRenderingSurfaceFor textLayoutFragment: NSTextLayoutFragment
    ) {}

    override func setNeedsLayout() {
        layoutRequests += 1
        super.setNeedsLayout()
    }

    @objc func extra() {
        extraMessages += 1
    }
}

final class TextViewportDelegateProxyTests: XCTestCase {
    private let controller = NSTextLayoutManager().textViewportLayoutController
    private let delegate = RecordingDelegate()
    private lazy var proxy = TextViewportDelegateProxy(wrapping: delegate, viewport: delegate.viewport)

    func testBoundsTheDelegatesViewport() {
        XCTAssertEqual(proxy.viewportBounds(for: controller), delegate.viewport)

        proxy.viewport = CGRect(x: 0, y: 300, width: 100, height: 200)
        XCTAssertEqual(proxy.viewportBounds(for: controller), CGRect(x: 0, y: 300, width: 100, height: 200))

        proxy.viewport = CGRect(x: 0, y: -50, width: 100, height: 200)
        XCTAssertEqual(proxy.viewportBounds(for: controller), CGRect(x: 0, y: 0, width: 100, height: 150))

        proxy.viewport = CGRect(x: 0, y: 5000, width: 100, height: 200)
        XCTAssertEqual(proxy.viewportBounds(for: controller), .zero, "no overlap is an empty viewport, not a null rect")
    }

    func testOtherMessagesReachTheDelegate() {
        XCTAssertTrue(proxy.responds(to: #selector(RecordingDelegate.extra)))
        XCTAssertFalse(proxy.responds(to: NSSelectorFromString("somethingNeitherImplements")))

        _ = proxy.perform(#selector(RecordingDelegate.extra))
        XCTAssertEqual(delegate.extraMessages, 1)
    }

    func testSettingTheViewportRequestsLayoutFromTheDelegate() {
        proxy.viewport = CGRect(x: 0, y: 300, width: 100, height: 200)
        XCTAssertEqual(delegate.layoutRequests, 1)
    }
}
