import UIKit
import XCTest
@testable import EnrichedMarkdown

final class AsyncRenderCoordinatorTests: XCTestCase {
    func testApplyRunsOnMainThread() {
        let coordinator = AsyncRenderCoordinator()
        let expectation = expectation(description: "apply on main")
        var appliedOnMain = false

        coordinator.scheduleRender({
            NSAttributedString(string: "hello")
        }, apply: { _ in
            appliedOnMain = Thread.isMainThread
            expectation.fulfill()
        })

        waitForExpectations(timeout: 2)
        XCTAssertTrue(appliedOnMain)
    }

    func testSecondRenderSupersedesFirst() {
        let coordinator = AsyncRenderCoordinator()
        let firstApply = expectation(description: "first apply")
        firstApply.isInverted = true
        let secondApply = expectation(description: "second apply")

        coordinator.scheduleRender({
            Thread.sleep(forTimeInterval: 0.05)
            return NSAttributedString(string: "first")
        }, apply: { _ in
            firstApply.fulfill()
        })

        coordinator.scheduleRender({
            NSAttributedString(string: "second")
        }, apply: { _ in
            secondApply.fulfill()
        })

        wait(for: [firstApply, secondApply], timeout: 2, enforceOrder: false)
    }

    func testInvalidateDropsPendingApply() {
        let coordinator = AsyncRenderCoordinator()
        let applyExpectation = expectation(description: "apply")
        applyExpectation.isInverted = true

        coordinator.scheduleRender({
            Thread.sleep(forTimeInterval: 0.05)
            return NSAttributedString(string: "stale")
        }, apply: { _ in
            applyExpectation.fulfill()
        })

        coordinator.invalidate()

        waitForExpectations(timeout: 0.2)
    }

    func testBlockAsyncRenderSkipsDispatch() {
        let coordinator = AsyncRenderCoordinator()
        coordinator.blockAsyncRender = true
        let applyExpectation = expectation(description: "apply")
        applyExpectation.isInverted = true

        coordinator.scheduleRender({
            NSAttributedString(string: "blocked")
        }, apply: { _ in
            applyExpectation.fulfill()
        })

        waitForExpectations(timeout: 0.1)
    }

    func testNilRenderResultSkipsApply() {
        let coordinator = AsyncRenderCoordinator()
        let applyExpectation = expectation(description: "apply")
        applyExpectation.isInverted = true

        coordinator.scheduleRender({
            nil
        }, apply: { _ in
            applyExpectation.fulfill()
        })

        waitForExpectations(timeout: 0.2)
    }
}
