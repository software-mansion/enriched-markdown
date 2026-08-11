import QuartzCore
import UIKit

/// Tracks what the editor is currently doing so delegate callbacks can tell a
/// change the user made from one the editor made to itself.
///
/// Text mutations performed while applying formatting or importing markdown
/// trigger the very same `UITextViewDelegate` callbacks as typing does. Without
/// a phase to check, those callbacks re-enter the code that caused them.
@available(iOS 16.0, *)
@MainActor
final class EditSession {
    enum Phase {
        case idle
        case processing
        case formatting
        case importing
    }

    private(set) var phase: Phase = .idle

    private weak var textView: UITextView?
    private let gracePeriod: CFTimeInterval
    private let now: () -> CFTimeInterval
    private var lastTextChangeTime: CFTimeInterval?

    init(
        gracePeriod: CFTimeInterval = 0.1,
        now: @escaping () -> CFTimeInterval = CACurrentMediaTime
    ) {
        self.gracePeriod = gracePeriod
        self.now = now
    }

    func attach(to textView: UITextView?) {
        self.textView = textView
    }

    /// Runs `body` in `phase`, then restores the phase that was active before.
    /// Restoring rather than resetting to `.idle` keeps an outer phase intact
    /// when another nests inside it, such as a reformat during an import.
    @discardableResult
    func withPhase<T>(_ phase: Phase, _ body: () throws -> T) rethrows -> T {
        let previous = self.phase
        self.phase = phase
        defer { self.phase = previous }
        return try body()
    }

    func recordTextChange() {
        lastTextChangeTime = now()
    }

    /// True while an input method or dictation has uncommitted marked text.
    var isComposing: Bool {
        textView?.markedTextRange != nil
    }

    /// True just after an edit, while selection callbacks are still catching up.
    var isPostEditGracePeriod: Bool {
        guard let lastTextChangeTime else { return false }
        return now() - lastTextChangeTime < gracePeriod
    }

    /// Reformatting during composition would discard the marked-text run and
    /// break the input method mid-word.
    var shouldSuppressFormatting: Bool {
        phase == .formatting || phase == .importing || isComposing
    }

    var shouldSuppressEvents: Bool {
        phase == .importing
    }

    var shouldSuppressSelectionSideEffects: Bool {
        phase != .idle
    }
}
