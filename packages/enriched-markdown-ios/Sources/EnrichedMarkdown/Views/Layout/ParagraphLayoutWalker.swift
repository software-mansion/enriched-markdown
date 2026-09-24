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
        let start = rect.flatMap { store.location(reaching: $0.minY, in: textLayoutManager) }
            ?? textLayoutManager.documentRange.location

        // No `.ensuresLayout`: the whole document is laid out before anything
        // draws (the text view never scrolls), and ensuring walks from the
        // document start.
        var paragraphs: [ParagraphLayout] = []
        textLayoutManager.enumerateTextLayoutFragments(from: start, options: []) { fragment in
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

    /// The paragraph laid out before `paragraph`, or nil at the document start.
    static func paragraph(before paragraph: ParagraphLayout, in textLayoutManager: NSTextLayoutManager) -> ParagraphLayout? {
        neighbor(of: paragraph, in: textLayoutManager) { range, contentStorage in
            contentStorage.location(range.location, offsetBy: -1)
        }
    }

    /// The paragraph laid out after `paragraph`, or nil at the document end.
    static func paragraph(after paragraph: ParagraphLayout, in textLayoutManager: NSTextLayoutManager) -> ParagraphLayout? {
        neighbor(of: paragraph, in: textLayoutManager) { range, _ in range.endLocation }
    }

    /// The paragraph at the location `locate` derives from the paragraph's range.
    private static func neighbor(
        of paragraph: ParagraphLayout,
        in textLayoutManager: NSTextLayoutManager,
        locate: (NSTextRange, NSTextContentStorage) -> NSTextLocation?
    ) -> ParagraphLayout? {
        guard let store = Store(textLayoutManager),
              let textRange = TextLayoutHelpers.textRange(paragraph.range, in: store.contentStorage),
              let location = locate(textRange, store.contentStorage),
              let fragment = textLayoutManager.textLayoutFragment(for: location),
              let neighbor = store.paragraph(for: fragment),
              neighbor.range != paragraph.range
        else { return nil }
        return neighbor
    }

    /// The attributed string behind a layout manager.
    private struct Store {
        let contentStorage: NSTextContentStorage
        let textStorage: NSTextStorage

        init?(_ textLayoutManager: NSTextLayoutManager) {
            guard let contentStorage = textLayoutManager.textContentManager as? NSTextContentStorage,
                  let textStorage = contentStorage.textStorage
            else { return nil }
            self.contentStorage = contentStorage
            self.textStorage = textStorage
        }

        /// The start of the first paragraph reaching below `edge`, found by
        /// bisecting character offsets: a fragment lookup by location is
        /// constant-time, where one by point walks from the document start.
        func location(reaching edge: CGFloat, in textLayoutManager: NSTextLayoutManager) -> NSTextLocation? {
            let documentStart = contentStorage.documentRange.location
            var low = 0
            var high = textStorage.length
            while low < high {
                guard let location = contentStorage.location(documentStart, offsetBy: (low + high) / 2),
                      let fragment = textLayoutManager.textLayoutFragment(for: location)
                else { return nil }
                if fragment.layoutFragmentFrame.maxY <= edge {
                    low = contentStorage.offset(from: documentStart, to: fragment.rangeInElement.endLocation)
                } else {
                    high = contentStorage.offset(from: documentStart, to: fragment.rangeInElement.location)
                }
            }
            return contentStorage.location(documentStart, offsetBy: low)
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
