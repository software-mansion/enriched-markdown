import UIKit

/// Keeps one overlay view per line segment of every concealed spoiler in a
/// text view, placed from TextKit 2 layout. Overlays are keyed by character
/// range plus segment ordinal. A re-layout that moves a segment without
/// changing its text, size or baseline moves the view, so an effect keeps
/// its state when content above it changes height, such as an image
/// finishing loading; one that changes what the segment shows replaces
/// the view.
@MainActor
final class SpoilerOverlayManager {
    private struct OverlayKey: Hashable {
        let range: NSRange
        let index: Int
    }

    private struct Segment {
        let frame: CGRect
        let range: NSRange
        let baseline: CGFloat
    }

    /// An overlay and the slice of text it was built from, as stored in
    /// the text view. That is the manager's bookkeeping, so it lives here
    /// rather than on the view.
    private struct PlacedOverlay {
        let view: SpoilerOverlayView
        let segmentRange: NSRange
        let source: NSAttributedString
    }

    /// TextKit reports fractionally different metrics for the same line
    /// between passes; anything within this counts as unchanged.
    private static let layoutTolerance: CGFloat = 0.5

    private weak var textView: UITextView?
    private var overlays: [OverlayKey: PlacedOverlay] = [:]
    /// Set when the text view replaces its text, and cleared once an
    /// `update` has compared the content of every overlay it kept.
    private var textChanged = false

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
        overlays.values.first { $0.view.frame.contains(point) }?.view.charRange
    }

    /// Fades out every overlay touching `range`. `point`, in text view
    /// coordinates, is where the reader tapped, or nil for a programmatic
    /// reveal. A fading overlay keeps its slot until the animation completes
    /// so `update` neither duplicates nor drops it.
    func reveal(range: NSRange, at point: CGPoint? = nil) {
        for (key, placed) in overlays where TextLayoutHelpers.rangesIntersect(placed.view.charRange, range) {
            let overlay = placed.view
            overlay.reveal(from: point.map { overlay.convert($0, from: textView) }) { [weak self] in
                self?.overlays.removeValue(forKey: key)
            }
        }
    }

    /// Called by the text view when it replaces its text.
    func textDidChange() {
        textChanged = true
    }

    /// Reconciles overlays with the text view's current text and layout.
    /// Runs on every layout pass: layout can change without a bounds or text
    /// change (an attachment resizing after its image loads), and with no
    /// spoilers the cost is one attribute enumeration.
    func update() {
        guard let textView, textView.bounds.width > 0 else { return }
        var desired = Set<OverlayKey>()

        for range in SpoilerInteraction.concealedRanges(in: textView.textStorage) {
            let segments = lineSegments(of: range, in: textView)
            for (index, segment) in segments.enumerated() {
                let key = OverlayKey(range: range, index: index)
                desired.insert(key)
                place(segment, at: key, segmentCount: segments.count, in: textView)
            }
        }

        for (key, placed) in overlays where !desired.contains(key) && !placed.view.isRevealing {
            placed.view.removeFromSuperview()
            overlays.removeValue(forKey: key)
        }
        textChanged = false
    }

    private func lineSegments(of range: NSRange, in textView: UITextView) -> [Segment] {
        var segments: [Segment] = []
        TextLayoutHelpers.enumerateSegmentFrames(of: range, in: textView) { frame, segmentRange, baseline in
            guard frame.width > 0, frame.height > 0 else { return }
            segments.append(Segment(frame: frame, range: segmentRange, baseline: baseline))
        }
        return segments
    }

    /// Moves the overlay at `key` onto `segment` when it still shows it, and
    /// otherwise replaces it with a new one from the provider.
    private func place(_ segment: Segment, at key: OverlayKey, segmentCount: Int, in textView: UITextView) {
        if let placed = overlays[key] {
            // A revealing overlay keeps its slot until its animation completes.
            guard !placed.view.isRevealing else { return }
            if shows(placed, segment, in: textView.textStorage) {
                placed.view.segmentCount = segmentCount
                if placed.view.frame != segment.frame { placed.view.frame = segment.frame }
                return
            }
            placed.view.removeFromSuperview()
        }

        let source = textView.textStorage.attributedSubstring(from: segment.range)
        let overlay = provider.makeOverlay(charRange: key.range, style: style)
        overlay.segmentIndex = key.index
        overlay.segmentCount = segmentCount
        overlay.concealedText = SpoilerInteraction.revealedText(of: source, in: NSRange(location: 0, length: source.length))
        overlay.baseline = segment.baseline
        overlay.frame = segment.frame
        textView.addSubview(overlay)
        overlays[key] = PlacedOverlay(view: overlay, segmentRange: segment.range, source: source)
    }

    /// Whether `placed` still shows `segment`, so moving it is enough.
    ///
    /// Within one text, the same range at the same size is the same glyphs.
    /// Only after a text change is the content compared as well, because
    /// slicing it costs an allocation per segment and this runs on every
    /// layout pass. The raw slice is compared, not the revealed copy the
    /// view draws, so the check skips building one. Attachments compare by
    /// identity, so a spoiler holding an inline image is replaced whenever
    /// the text is replaced.
    private func shows(_ placed: PlacedOverlay, _ segment: Segment, in textStorage: NSTextStorage) -> Bool {
        let view = placed.view
        let tolerance = Self.layoutTolerance
        guard placed.segmentRange == segment.range,
              abs(view.frame.width - segment.frame.width) < tolerance,
              abs(view.frame.height - segment.frame.height) < tolerance,
              abs(view.baseline - segment.baseline) < tolerance
        else { return false }
        guard textChanged else { return true }
        return placed.source.isEqual(to: textStorage.attributedSubstring(from: segment.range))
    }

    private func rebuild() {
        overlays.values.forEach { $0.view.removeFromSuperview() }
        overlays.removeAll()
        update()
    }
}
