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

    private struct Segment {
        let frame: CGRect
        let range: NSRange
        let baseline: CGFloat
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
            var segments: [Segment] = []
            TextLayoutHelpers.enumerateSegmentFrames(of: range, in: textView) { frame, segmentRange, baseline in
                guard frame.width > 0, frame.height > 0 else { return }
                segments.append(Segment(frame: frame, range: segmentRange, baseline: baseline))
            }

            for (index, segment) in segments.enumerated() {
                let key = OverlayKey(range: range, frame: segment.frame.integral)
                desired.insert(key)
                let overlay = overlays[key] ?? provider.makeOverlay(charRange: range, style: style)
                // Order can change without this segment moving, e.g. when
                // the line above it wraps differently.
                overlay.segmentIndex = index
                overlay.segmentCount = segments.count
                guard overlays[key] == nil else { continue }

                overlay.concealedText = SpoilerInteraction.revealedText(of: textStorage, in: segment.range)
                overlay.baseline = segment.baseline
                overlay.frame = segment.frame
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
