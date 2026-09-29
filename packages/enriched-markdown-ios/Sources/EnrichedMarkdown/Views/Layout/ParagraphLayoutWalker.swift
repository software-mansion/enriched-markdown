import UIKit

/// One laid-out line of a paragraph, in text container coordinates.
struct LineLayout {
    /// The line's typographic bounds.
    let bounds: CGRect
    /// The baseline, measured down from `bounds.minY`.
    let baselineOffset: CGFloat
}

/// One paragraph as TextKit 2 laid it out.
struct ParagraphLayout {
    let range: NSRange
    /// The attributes at the paragraph's first character.
    let attributes: [NSAttributedString.Key: Any]
    let lines: [LineLayout]

    /// The union of the lines' bounds; `.null` for a paragraph with none.
    var frame: CGRect {
        lines.reduce(CGRect.null) { $0.union($1.bounds) }
    }
}

/// Reads paragraph geometry from the layout fragments rather than from
/// `enumerateTextSegments(in:)`, which costs time proportional to the
/// range's position in the document: asked once per paragraph, it made a
/// draw quadratic in document length (seconds for a long list). The
/// fragments hand out the same line bounds and baselines.
enum ParagraphLayoutWalker {
    /// The paragraphs whose layout intersects `rect` (text container
    /// coordinates; nil for every paragraph), in document order.
    static func paragraphs(
        in textLayoutManager: NSTextLayoutManager,
        intersecting rect: CGRect? = nil
    ) -> [ParagraphLayout] {
        guard let store = Store(textLayoutManager) else { return [] }
        let start = rect.flatMap { store.location(reaching: $0.minY) } ?? textLayoutManager.documentRange.location

        // No `.ensuresLayout`, which walks from the document start: layout
        // precedes every draw, see `Store.laidOut(_:)`.
        var paragraphs: [ParagraphLayout] = []
        textLayoutManager.enumerateTextLayoutFragments(from: start, options: []) { probed in
            let fragment = store.laidOut(probed)
            if let rect, fragment.layoutFragmentFrame.minY >= rect.maxY {
                return false
            }
            if let paragraph = store.paragraph(for: fragment) {
                paragraphs.append(paragraph)
            }
            return true
        }
        return paragraphs
    }

    /// The paragraph containing the character at `offset`, or nil past the end.
    static func paragraph(containing offset: Int, in textLayoutManager: NSTextLayoutManager) -> ParagraphLayout? {
        guard let store = Store(textLayoutManager),
              offset >= 0, offset < store.textStorage.length,
              let location = store.location(at: offset),
              let fragment = textLayoutManager.textLayoutFragment(for: location)
        else { return nil }
        return store.paragraph(for: store.laidOut(fragment))
    }

    /// A layout manager with the attributed string behind it.
    private struct Store {
        let textLayoutManager: NSTextLayoutManager
        let contentStorage: NSTextContentStorage
        let textStorage: NSTextStorage

        init?(_ textLayoutManager: NSTextLayoutManager) {
            guard let contentStorage = textLayoutManager.textContentManager as? NSTextContentStorage,
                  let textStorage = contentStorage.textStorage
            else { return nil }
            self.textLayoutManager = textLayoutManager
            self.contentStorage = contentStorage
            self.textStorage = textStorage
        }

        func location(at offset: Int) -> NSTextLocation? {
            contentStorage.location(contentStorage.documentRange.location, offsetBy: offset)
        }

        func offset(of location: NSTextLocation) -> Int {
            contentStorage.offset(from: contentStorage.documentRange.location, to: location)
        }

        /// The start of the first paragraph reaching below `edge`, found by
        /// bisecting character offsets: a fragment lookup by location is
        /// constant-time, where one by point walks from the document start.
        func location(reaching edge: CGFloat) -> NSTextLocation? {
            var low = 0
            var high = textStorage.length
            while low < high {
                guard let location = location(at: (low + high) / 2),
                      let probed = textLayoutManager.textLayoutFragment(for: location)
                else { return nil }
                let fragment = laidOut(probed)
                if fragment.layoutFragmentFrame.maxY <= edge {
                    low = offset(of: fragment.rangeInElement.endLocation)
                } else {
                    high = offset(of: fragment.rangeInElement.location)
                }
            }
            return location(at: low)
        }

        /// The fragment with its layout done. That is normally already so: a
        /// tile lies inside the text view's bounds, which is the TextKit viewport
        /// of a text view that does not scroll, and Core Animation lays that
        /// viewport out before it displays the decoration views. A host that
        /// draws earlier, or a scrolling text view asked about a region outside
        /// its viewport, gets the fragment laid out here, at the price of a walk
        /// from the document start; before that its frame and lines are empty.
        func laidOut(_ fragment: NSTextLayoutFragment) -> NSTextLayoutFragment {
            guard fragment.state != .layoutAvailable else { return fragment }
            textLayoutManager.ensureLayout(for: fragment.rangeInElement)
            return textLayoutManager.textLayoutFragment(for: fragment.rangeInElement.location) ?? fragment
        }

        func paragraph(for fragment: NSTextLayoutFragment) -> ParagraphLayout? {
            guard let range = TextLayoutHelpers.nsRange(fragment.rangeInElement, in: contentStorage),
                  range.length > 0, range.location < textStorage.length
            else { return nil }

            let origin = fragment.layoutFragmentFrame.origin
            return ParagraphLayout(
                range: range,
                attributes: textStorage.attributes(at: range.location, effectiveRange: nil),
                lines: fragment.textLineFragments.map { line in
                    LineLayout(
                        bounds: line.typographicBounds.offsetBy(dx: origin.x, dy: origin.y),
                        baselineOffset: line.glyphOrigin.y
                    )
                }
            )
        }
    }
}
