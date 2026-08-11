import QuartzCore
import UIKit
import XCTest
@testable import EnrichedMarkdown

@available(iOS 16.0, *)
@MainActor
final class EditSessionTests: XCTestCase {
    private var clock: CFTimeInterval = 0

    private func makeSession(gracePeriod: CFTimeInterval = 0.1) -> EditSession {
        EditSession(gracePeriod: gracePeriod, now: { [unowned self] in self.clock })
    }

    // MARK: - Phases

    func testStartsIdle() {
        XCTAssertEqual(makeSession().phase, .idle)
    }

    func testWithPhaseAppliesPhaseForDurationOfBody() {
        let session = makeSession()

        session.withPhase(.formatting) {
            XCTAssertEqual(session.phase, .formatting)
        }

        XCTAssertEqual(session.phase, .idle)
    }

    func testNestedPhaseRestoresOuterPhase() {
        let session = makeSession()

        session.withPhase(.importing) {
            session.withPhase(.formatting) {
                XCTAssertEqual(session.phase, .formatting)
            }
            XCTAssertEqual(session.phase, .importing, "inner phase must not reset the outer one to idle")
        }

        XCTAssertEqual(session.phase, .idle)
    }

    func testWithPhaseRestoresPhaseWhenBodyThrows() {
        let session = makeSession()
        struct Failure: Error {}

        XCTAssertThrowsError(
            try session.withPhase(.importing) { throw Failure() }
        )
        XCTAssertEqual(session.phase, .idle)
    }

    func testWithPhaseReturnsBodyResult() {
        XCTAssertEqual(makeSession().withPhase(.processing) { 42 }, 42)
    }

    // MARK: - Suppression queries

    func testSuppressesEventsOnlyWhileImporting() {
        let session = makeSession()
        XCTAssertFalse(session.shouldSuppressEvents)

        session.withPhase(.importing) { XCTAssertTrue(session.shouldSuppressEvents) }
        session.withPhase(.formatting) { XCTAssertFalse(session.shouldSuppressEvents) }
        session.withPhase(.processing) { XCTAssertFalse(session.shouldSuppressEvents) }
    }

    func testSuppressesFormattingWhileFormattingOrImporting() {
        let session = makeSession()
        XCTAssertFalse(session.shouldSuppressFormatting)

        session.withPhase(.formatting) { XCTAssertTrue(session.shouldSuppressFormatting) }
        session.withPhase(.importing) { XCTAssertTrue(session.shouldSuppressFormatting) }
        session.withPhase(.processing) { XCTAssertFalse(session.shouldSuppressFormatting) }
    }

    func testSuppressesSelectionSideEffectsWheneverNotIdle() {
        let session = makeSession()
        XCTAssertFalse(session.shouldSuppressSelectionSideEffects)

        for phase in [EditSession.Phase.processing, .formatting, .importing] {
            session.withPhase(phase) {
                XCTAssertTrue(session.shouldSuppressSelectionSideEffects, "\(phase) must suppress")
            }
        }
    }

    // MARK: - Grace period

    func testGracePeriodInactiveBeforeAnyTextChange() {
        XCTAssertFalse(makeSession().isPostEditGracePeriod)
    }

    func testGracePeriodActiveImmediatelyAfterTextChange() {
        let session = makeSession(gracePeriod: 0.1)
        session.recordTextChange()

        XCTAssertTrue(session.isPostEditGracePeriod)
    }

    func testGracePeriodExpiresAfterInterval() {
        let session = makeSession(gracePeriod: 0.1)
        session.recordTextChange()

        clock += 0.05
        XCTAssertTrue(session.isPostEditGracePeriod)

        clock += 0.06
        XCTAssertFalse(session.isPostEditGracePeriod)
    }

    // MARK: - Composition

    func testNotComposingWithoutTextView() {
        XCTAssertFalse(makeSession().isComposing)
    }

    func testNotComposingWhenTextViewHasNoMarkedText() {
        let session = makeSession()
        session.attach(to: UITextView())

        XCTAssertFalse(session.isComposing)
        XCTAssertFalse(session.shouldSuppressFormatting)
    }
}
