import UIKit

@MainActor
final class StreamingTransitionManager {
    private struct Overlay {
        let view: UIImageView
        let range: NSRange
        var isDone = false
    }

    private final class Run {
        let transition: any ViewTransition
        var pieces: [NSRange]
        var overlays: [Overlay] = []

        init(transition: any ViewTransition, pieces: [NSRange]) {
            self.transition = transition
            self.pieces = pieces
        }
    }

    private static let stash = MarkdownAttribute.streamingOriginalColors

    var transition: (any ViewTransition)?

    var activeTransition: (any ViewTransition)? {
        guard let transition, !UIAccessibility.isReduceMotionEnabled else { return nil }
        return transition
    }

    private weak var textView: UITextView?
    private var runs: [Run] = []
    private var pendingAttachments: Set<Int> = []

    init(textView: UITextView) {
        self.textView = textView
    }

    func insert(_ range: NSRange) {
        guard let transition = activeTransition, let storage = textView?.textStorage, range.length > 0 else { return }

        var pieces: [NSRange] = []
        storage.enumerateAttribute(.attachment, in: range) { value, run, _ in
            if value is NSTextAttachment {
                pendingAttachments.insert(run.location)
            } else {
                pieces.append(run)
            }
        }
        guard !pieces.isEmpty else { return }

        editingStorage { storage in
            for piece in pieces {
                ColorConcealment.conceal(storage, in: piece, stash: Self.stash)
            }
        }
        runs.append(Run(transition: transition, pieces: pieces))
    }

    func textWillChange(from location: Int) {
        pendingAttachments = pendingAttachments.filter { $0 < location }
        editingStorage { storage in
            for run in runs {
                run.pieces = run.pieces.compactMap { piece in
                    let end = max(piece.location, min(NSMaxRange(piece), location))
                    if NSMaxRange(piece) > end {
                        ColorConcealment.reveal(storage, in: NSRange(location: end, length: NSMaxRange(piece) - end), stash: Self.stash)
                    }
                    return end > piece.location ? NSRange(location: piece.location, length: end - piece.location) : nil
                }
            }
        }
        for run in runs where run.pieces.isEmpty {
            finish(run)
        }
    }

    func discard() {
        for run in runs {
            removeOverlays(of: run)
        }
        runs.removeAll()
        pendingAttachments.removeAll()
    }

    func update() {
        guard let textView, textView.bounds.width > 0 else { return }
        animateInstalledAttachmentViews(in: textView)
        for run in runs {
            place(run, in: textView)
        }
    }

    private func place(_ run: Run, in textView: UITextView) {
        let segments = run.pieces.flatMap { TextLayoutHelpers.lineSegments(of: $0, in: textView) }
        var fresh: [UIImageView] = []
        let overlays = segments.map { segment -> Overlay in
            if let overlay = run.overlays.first(where: { $0.range == segment.range }) {
                let center = CGPoint(x: segment.frame.midX, y: segment.frame.midY)
                if overlay.view.center != center {
                    overlay.view.center = center
                }
                return overlay
            }
            let view = makeOverlay(for: segment, in: textView)
            fresh.append(view)
            return Overlay(view: view, range: segment.range)
        }
        for stale in run.overlays where !overlays.contains(where: { $0.view === stale.view }) {
            stale.view.removeFromSuperview()
        }
        run.overlays = overlays
        guard !overlays.isEmpty else {
            finish(run)
            return
        }
        for view in fresh {
            run.transition.animate(view) { [weak self] in
                self?.overlayDidFinish(view)
            }
        }
    }

    private func makeOverlay(for segment: TextLayoutHelpers.LineSegment, in textView: UITextView) -> UIImageView {
        let slice = NSMutableAttributedString(attributedString: textView.textStorage.attributedSubstring(from: segment.range))
        ColorConcealment.reveal(slice, in: NSRange(location: 0, length: slice.length), stash: Self.stash)
        let image = TextSlice.image(
            of: TextSlice.standalone(slice),
            size: segment.frame.size,
            baseline: segment.baseline,
            traits: textView.traitCollection
        )
        let view = UIImageView(image: image)
        view.frame = segment.frame
        textView.addSubview(view)
        return view
    }

    private func overlayDidFinish(_ view: UIView) {
        for run in runs {
            guard let index = run.overlays.firstIndex(where: { $0.view === view }) else { continue }
            run.overlays[index].isDone = true
            if run.overlays.allSatisfy(\.isDone) {
                finish(run)
            }
            return
        }
    }

    private func finish(_ run: Run) {
        editingStorage { storage in
            for piece in run.pieces {
                ColorConcealment.reveal(storage, in: piece, stash: Self.stash)
            }
        }
        removeOverlays(of: run)
        runs.removeAll { $0 === run }
    }

    private func removeOverlays(of run: Run) {
        for overlay in run.overlays {
            overlay.view.removeFromSuperview()
        }
    }

    private func animateInstalledAttachmentViews(in textView: UITextView) {
        defer { pendingAttachments.removeAll() }
        guard let transition = activeTransition,
              let start = pendingAttachments.min(),
              let textLayoutManager = textView.textLayoutManager,
              let contentManager = textLayoutManager.textContentManager,
              let location = contentManager.location(contentManager.documentRange.location, offsetBy: start)
        else { return }
        textLayoutManager.enumerateTextLayoutFragments(from: location) { fragment in
            for provider in fragment.textAttachmentViewProviders {
                let offset = contentManager.offset(from: contentManager.documentRange.location, to: provider.location)
                guard pendingAttachments.remove(offset) != nil, let view = provider.view else { continue }
                if let block = view as? StreamingBlockView {
                    block.animateContentIn(with: transition)
                } else {
                    transition.animate(view) {}
                }
            }
            return !pendingAttachments.isEmpty
        }
    }

    private func editingStorage(_ edits: (NSTextStorage) -> Void) {
        guard let storage = textView?.textStorage else { return }
        storage.beginEditing()
        edits(storage)
        storage.endEditing()
    }
}
