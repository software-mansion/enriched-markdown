import UIKit

/// Keeps one overlay view per line segment of every concealed spoiler in a
/// text view, placed from TextKit 2 layout. Overlays are keyed by character
/// range plus frame, so a re-layout that moves nothing is a no-op and a
/// change replaces only the segments that moved.
@MainActor
final class SpoilerOverlayManager {
    private struct OverlayKey: Hashable {
        let range: NSRange
        let frame: CGRect
    }

    private weak var textView: UITextView?
    private var overlays: [OverlayKey: SpoilerOverlayView] = [:]

    var provider: any SpoilerOverlayProvider = ParticleSpoilerOverlayProvider() {
        didSet {
            guard !provider.isEqual(to: oldValue) else { return }
            rebuild()
        }
    }

    var style: SpoilerStyle {
        didSet {
            guard style != oldValue else { return }
            rebuild()
        }
    }

    init(textView: UITextView, style: SpoilerStyle) {
        self.textView = textView
        self.style = style
    }

    /// Character range of the spoiler under `point` (text view coordinates).
    func concealedRange(at point: CGPoint) -> NSRange? {
        overlays.values.first { $0.frame.contains(point) }?.charRange
    }

    /// Fades out every overlay touching `range`. A fading overlay keeps its
    /// slot until the animation completes so `update` neither duplicates nor
    /// drops it.
    func reveal(range: NSRange) {
        for (key, overlay) in overlays where TextLayoutHelpers.rangesIntersect(overlay.charRange, range) {
            overlay.reveal { [weak self] in
                self?.overlays.removeValue(forKey: key)
            }
        }
    }

    /// Reconciles overlays with the text view's current text and layout.
    /// Runs on every layout pass: layout can change without a bounds or text
    /// change (an attachment resizing after its image loads), and with no
    /// spoilers the cost is one attribute enumeration.
    func update() {
        guard let textView, textView.bounds.width > 0 else { return }
        let textStorage = textView.textStorage
        var desired = Set<OverlayKey>()

        for range in SpoilerInteraction.concealedRanges(in: textStorage) {
            TextLayoutHelpers.enumerateSegmentFrames(of: range, in: textView) { frame, segmentRange in
                guard frame.width > 0, frame.height > 0 else { return }
                let key = OverlayKey(range: range, frame: frame.integral)
                desired.insert(key)
                guard overlays[key] == nil else { return }

                let overlay = provider.makeOverlay(charRange: range, style: style)
                overlay.concealedText = SpoilerInteraction.revealedText(of: textStorage, in: segmentRange)
                overlay.frame = frame
                textView.addSubview(overlay)
                overlays[key] = overlay
            }
        }

        for (key, overlay) in overlays where !desired.contains(key) && !overlay.isRevealing {
            overlay.removeFromSuperview()
            overlays.removeValue(forKey: key)
        }
    }

    private func rebuild() {
        overlays.values.forEach { $0.removeFromSuperview() }
        overlays.removeAll()
        update()
    }
}
