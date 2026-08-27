import UIKit

/// Maps a rendered-text selection back to a verbatim slice of the original
/// markdown source, using the `MarkdownAttribute.sourceRange` byte offsets
/// the renderer copies onto text runs.
///
/// The slice is the byte union of the selected runs' source ranges, expanded
/// outward over adjacent syntax the selection visually includes: inline
/// markers around fully-selected spans, block prefixes (list markers,
/// blockquote bars, heading hashes) when the selection starts a line's text,
/// code fences around fully-selected blocks, table row edges, image
/// `![...](...)` syntax, and setext underlines. Every candidate slice is
/// validated by re-parsing it — its literal text and its table/image/break
/// structure must match the selection's — so a bad mapping (mis-anchored
/// offsets, unbalanced markers) returns nil and the caller falls back to
/// reconstruction, never wrong output. Runs without offsets return nil.
enum MarkdownSourceSlicer {
    static func slice(
        for selection: NSRange,
        in attributedText: NSAttributedString,
        source: String,
        flags: Md4cFlags
    ) -> String? {
        let bytes = Array(source.utf8)
        guard let runs = mappedRuns(in: selection, of: attributedText, sourceByteCount: bytes.count),
              let firstRun = runs.first,
              let lastRun = runs.last else {
            return nil
        }

        guard var start = snapStart(
            firstRun.byteRange.lowerBound,
            run: firstRun,
            selection: selection,
            in: attributedText,
            bytes: bytes
        ), var end = snapEnd(
            lastRun.byteRange.upperBound,
            run: lastRun,
            selection: selection,
            in: attributedText,
            bytes: bytes
        ) else {
            return nil
        }

        start = expandOpeningFence(from: start, run: firstRun, bytes: bytes)
        end = expandClosingFence(from: end, run: lastRun, bytes: bytes)
        start = expandTableStart(from: start, run: firstRun, bytes: bytes)
        end = expandTableEnd(from: end, run: lastRun, bytes: bytes)
        end = expandSetextUnderline(from: end, run: lastRun, bytes: bytes)
        start = expandBlockPrefix(from: start, bytes: bytes)

        guard start < end, end <= bytes.count,
              let slice = String(bytes: bytes[start..<end], encoding: .utf8),
              MarkdownSliceValidator.isFaithful(
                slice, toSelection: selection, in: attributedText, flags: flags
              ) else {
            return nil
        }
        return slice
    }
}

private extension MarkdownSourceSlicer {
    struct MappedRun {
        let byteRange: Range<Int>
        let nodeByteRange: Range<Int>
        let runRange: NSRange
        let attrs: [NSAttributedString.Key: Any]
    }

    /// Byte ranges for every visible run in the selection, or nil when any
    /// visible run has no mapping (attachments, escapes, entities). A run
    /// partially covered by the selection is narrowed to the covered bytes.
    static func mappedRuns(
        in selection: NSRange,
        of attributedText: NSAttributedString,
        sourceByteCount: Int
    ) -> [MappedRun]? {
        let string = attributedText.string as NSString
        let fullRange = NSRange(location: 0, length: attributedText.length)
        var runs: [MappedRun] = []
        var failed = false

        attributedText.enumerateAttributes(in: selection, options: []) { attrs, runRange, stop in
            if attrs[.attachment] != nil {
                // Attachments map all-or-nothing: their placeholder is a
                // single character, so the node range is never narrowed.
                guard let value = attrs[MarkdownAttribute.sourceRange] as? NSValue,
                      value.rangeValue.length > 0,
                      NSMaxRange(value.rangeValue) <= sourceByteCount else {
                    failed = true
                    stop.pointee = true
                    return
                }
                let nodeRange = value.rangeValue.location..<NSMaxRange(value.rangeValue)
                runs.append(MappedRun(
                    byteRange: nodeRange,
                    nodeByteRange: nodeRange,
                    runRange: runRange,
                    attrs: attrs
                ))
                return
            }
            let text = string.substring(with: runRange)
            if isInvisible(text) {
                return
            }
            guard let value = attrs[MarkdownAttribute.sourceRange] as? NSValue else {
                failed = true
                stop.pointee = true
                return
            }

            let sourceRange = value.rangeValue
            var nodeRange = NSRange()
            _ = attributedText.attribute(
                MarkdownAttribute.sourceRange,
                at: runRange.location,
                longestEffectiveRange: &nodeRange,
                in: fullRange
            )
            let prefix = NSRange(
                location: nodeRange.location,
                length: runRange.location - nodeRange.location
            )
            let suffix = NSRange(
                location: NSMaxRange(runRange),
                length: NSMaxRange(nodeRange) - NSMaxRange(runRange)
            )
            let start = sourceRange.location + string.substring(with: prefix).utf8.count
            let end = NSMaxRange(sourceRange) - string.substring(with: suffix).utf8.count
            guard start < end, end <= sourceByteCount else {
                failed = true
                stop.pointee = true
                return
            }
            runs.append(MappedRun(
                byteRange: start..<end,
                nodeByteRange: sourceRange.location..<NSMaxRange(sourceRange),
                runRange: runRange,
                attrs: attrs
            ))
        }

        return failed || runs.isEmpty ? nil : runs
    }

    static func isInvisible(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy { MarkdownExtractor.invisibleCharacters.contains($0) }
    }

    // MARK: - Inline marker snapping

    enum EdgeTrait: CaseIterable {
        case inlineCode
        case strikethrough
        case underline
        case emphasis
        case strong
        case link
        case image

        var key: NSAttributedString.Key {
            switch self {
            case .inlineCode: return MarkdownAttribute.inlineCode
            case .strikethrough: return .strikethroughStyle
            case .underline: return .underlineStyle
            case .emphasis: return MarkdownAttribute.emphasis
            case .strong: return MarkdownAttribute.strong
            case .link: return .link
            case .image: return .attachment
            }
        }

        /// A trait whose markers must be consumed or the slice aborted — a
        /// plain slice would silently drop the element (a link's destination,
        /// an image's syntax).
        var requiresMatch: Bool {
            self == .link || self == .image
        }

        func isActive(_ traits: MarkdownExtractor.InlineTraits, attrs: [NSAttributedString.Key: Any]) -> Bool {
            switch self {
            case .inlineCode: return traits.isInlineCode && traits.linkURL == nil
            case .strikethrough: return traits.isStrikethrough
            case .underline: return traits.isUnderline && traits.linkURL == nil
            case .emphasis: return traits.isEmphasis
            case .strong: return traits.isStrong
            case .link: return traits.linkURL != nil
            case .image: return attrs[.attachment] is MarkdownImageAttachment
            }
        }

        func consumeOpening(in bytes: [UInt8], before index: Int) -> Int? {
            switch self {
            case .inlineCode:
                return MarkdownSourceSlicer.consumeBackticksBackward(in: bytes, before: index)
            case .strikethrough:
                return MarkdownSourceSlicer.matchBackward("~~", in: bytes, before: index)
            case .underline:
                return MarkdownSourceSlicer.matchBackward("<u>", in: bytes, before: index)
            case .emphasis, .strong:
                let markers = self == .strong ? ["**", "__"] : ["*", "_"]
                return markers
                    .compactMap { MarkdownSourceSlicer.matchBackward($0, in: bytes, before: index) }
                    .first
            case .link:
                return MarkdownSourceSlicer.matchBackward("[", in: bytes, before: index)
            case .image:
                // The mapped range covers only the alt text.
                return MarkdownSourceSlicer.matchBackward("![", in: bytes, before: index)
            }
        }

        func consumeClosing(in bytes: [UInt8], from index: Int) -> Int? {
            switch self {
            case .inlineCode:
                return MarkdownSourceSlicer.consumeBackticksForward(in: bytes, from: index)
            case .strikethrough:
                return MarkdownSourceSlicer.matchForward("~~", in: bytes, at: index)
            case .underline:
                return MarkdownSourceSlicer.matchForward("</u>", in: bytes, at: index)
            case .emphasis, .strong:
                let markers = self == .strong ? ["**", "__"] : ["*", "_"]
                return markers
                    .compactMap { MarkdownSourceSlicer.matchForward($0, in: bytes, at: index) }
                    .first
            case .link, .image:
                return MarkdownSourceSlicer.consumeLinkSuffix(in: bytes, from: index)
            }
        }
    }

    /// Traits whose full rendered span lies inside the selection — only then
    /// are BOTH of the span's marker sides selected (adjacent to an edge or
    /// interior to the byte union), so consuming one edge keeps the slice
    /// balanced.
    static func coveredTraits(
        of run: MappedRun,
        selection: NSRange,
        in attributedText: NSAttributedString
    ) -> [EdgeTrait] {
        let inlineTraits = MarkdownExtractor.InlineTraits(attrs: run.attrs)
        let fullRange = NSRange(location: 0, length: attributedText.length)
        return EdgeTrait.allCases.filter { trait in
            guard trait.isActive(inlineTraits, attrs: run.attrs) else { return false }
            var span = NSRange()
            guard attributedText.attribute(
                trait.key, at: run.runRange.location, longestEffectiveRange: &span, in: fullRange
            ) != nil else { return false }
            return NSIntersectionRange(span, selection) == span
        }
    }

    /// Expands `start` backward over the opening markers of fully-selected
    /// spans; nil when a `requiresMatch` trait's markers are missing
    /// (reference links, autolinks) and the caller must fall back.
    static func snapStart(
        _ start: Int,
        run: MappedRun,
        selection: NSRange,
        in attributedText: NSAttributedString,
        bytes: [UInt8]
    ) -> Int? {
        guard start == run.nodeByteRange.lowerBound else { return start }
        if run.attrs[.attachment] != nil, !(run.attrs[.attachment] is MarkdownImageAttachment) {
            return start
        }
        return consumeTraits(
            coveredTraits(of: run, selection: selection, in: attributedText),
            from: start
        ) { trait, position in
            trait.consumeOpening(in: bytes, before: position)
        }
    }

    /// Forward counterpart of `snapStart`.
    static func snapEnd(
        _ end: Int,
        run: MappedRun,
        selection: NSRange,
        in attributedText: NSAttributedString,
        bytes: [UInt8]
    ) -> Int? {
        guard end == run.nodeByteRange.upperBound else { return end }
        if run.attrs[.attachment] != nil, !(run.attrs[.attachment] is MarkdownImageAttachment) {
            return end
        }
        return consumeTraits(
            coveredTraits(of: run, selection: selection, in: attributedText),
            from: end
        ) { trait, position in
            trait.consumeClosing(in: bytes, from: position)
        }
    }

    /// Consumes each trait's markers at most once, retrying until no trait
    /// progresses (nesting means markers unlock each other in any order);
    /// nil when a `requiresMatch` trait cannot consume.
    static func consumeTraits(
        _ traits: [EdgeTrait],
        from position: Int,
        consume: (EdgeTrait, Int) -> Int?
    ) -> Int? {
        var result = position
        var remaining = traits
        var progressed = true
        while progressed {
            progressed = false
            for (index, trait) in remaining.enumerated() {
                if let next = consume(trait, result) {
                    result = next
                    remaining.remove(at: index)
                    progressed = true
                    break
                }
                if trait.requiresMatch {
                    return nil
                }
            }
        }
        return result
    }

    static func matchBackward(_ marker: String, in bytes: [UInt8], before index: Int) -> Int? {
        let start = index - marker.utf8.count
        guard start >= 0, bytes[start..<index].elementsEqual(marker.utf8) else { return nil }
        return start
    }

    static func matchForward(_ marker: String, in bytes: [UInt8], at index: Int) -> Int? {
        let end = index + marker.utf8.count
        guard end <= bytes.count, bytes[index..<end].elementsEqual(marker.utf8) else { return nil }
        return end
    }

    static func consumeBackticksBackward(in bytes: [UInt8], before index: Int) -> Int? {
        var start = index
        while start > 0, bytes[start - 1] == UInt8(ascii: "`") {
            start -= 1
        }
        return start < index ? start : nil
    }

    static func consumeBackticksForward(in bytes: [UInt8], from index: Int) -> Int? {
        var end = index
        while end < bytes.count, bytes[end] == UInt8(ascii: "`") {
            end += 1
        }
        return end > index ? end : nil
    }

    /// Consumes `](destination)` with balanced parentheses, bounded so a
    /// pathological source cannot scan far.
    static func consumeLinkSuffix(in bytes: [UInt8], from index: Int) -> Int? {
        guard matchForward("](", in: bytes, at: index) != nil else { return nil }
        var depth = 1
        var cursor = index + 2
        let limit = min(bytes.count, cursor + 4096)
        while cursor < limit {
            switch bytes[cursor] {
            case UInt8(ascii: "("):
                depth += 1
            case UInt8(ascii: ")"):
                depth -= 1
                if depth == 0 {
                    return cursor + 1
                }
            default:
                break
            }
            cursor += 1
        }
        return nil
    }

    // MARK: - Block expansion

    static func lineStart(before index: Int, in bytes: [UInt8]) -> Int {
        var start = index
        while start > 0, bytes[start - 1] != UInt8(ascii: "\n") {
            start -= 1
        }
        return start
    }

    static func lineEnd(from index: Int, in bytes: [UInt8]) -> Int {
        var end = index
        while end < bytes.count, bytes[end] != UInt8(ascii: "\n") {
            end += 1
        }
        return end
    }

    /// Extends `start` to the start of its line when every byte in between
    /// is block-prefix syntax (indentation, blockquote bars, a list marker
    /// with optional task box, heading hashes) — the selection then starts
    /// the line's text, so its markers are visually included.
    static func expandBlockPrefix(from start: Int, bytes: [UInt8]) -> Int {
        let line = lineStart(before: start, in: bytes)
        guard line < start, isBlockPrefix(bytes[line..<start]) else { return start }
        return line
    }

    static func isBlockPrefix(_ slice: ArraySlice<UInt8>) -> Bool {
        var scanner = MarkdownBlockPrefixScanner(slice: slice)
        scanner.consumeIndentAndBars()
        if scanner.consumeListMarker() {
            scanner.consumeTaskBox()
        }
        scanner.consumeHeadingHashes()
        return scanner.isAtEnd
    }

    // MARK: - Code fences

    static func isCodeBlockRun(_ run: MappedRun) -> Bool {
        MarkdownAttributeValue.boolValue(from: run.attrs[MarkdownAttribute.codeBlock])
    }

    /// A fully-selected code block starts at its content's first byte; the
    /// opening fence is the previous line.
    static func expandOpeningFence(from start: Int, run: MappedRun, bytes: [UInt8]) -> Int {
        guard isCodeBlockRun(run),
              start == run.nodeByteRange.lowerBound,
              start > 0,
              bytes[start - 1] == UInt8(ascii: "\n") else {
            return start
        }
        let fenceLine = lineStart(before: start - 1, in: bytes)
        guard isFenceLine(bytes[fenceLine..<(start - 1)], requireBare: false) else { return start }
        return fenceLine
    }

    /// Code content includes its trailing newline, so a fully-selected block
    /// ends where the closing fence's line begins.
    static func expandClosingFence(from end: Int, run: MappedRun, bytes: [UInt8]) -> Int {
        guard isCodeBlockRun(run), end == run.nodeByteRange.upperBound else { return end }
        let fenceEnd = lineEnd(from: end, in: bytes)
        guard isFenceLine(bytes[end..<fenceEnd], requireBare: true) else { return end }
        return fenceEnd
    }

    // MARK: - Tables and setext headings

    /// A table's aggregated range starts at the first header cell's text and
    /// ends at the last cell's text; the row pipes live on the same lines.
    static func expandTableStart(from start: Int, run: MappedRun, bytes: [UInt8]) -> Int {
        run.attrs[.attachment] is TableAttachment ? lineStart(before: start, in: bytes) : start
    }

    static func expandTableEnd(from end: Int, run: MappedRun, bytes: [UInt8]) -> Int {
        run.attrs[.attachment] is TableAttachment ? lineEnd(from: end, in: bytes) : end
    }

    /// A `---`/`===` underline directly after a fully-selected heading whose
    /// own line has no `#` (after an ATX heading the same line would be a
    /// thematic break, which must stay out).
    static func expandSetextUnderline(from end: Int, run: MappedRun, bytes: [UInt8]) -> Int {
        guard MarkdownAttributeValue.intValue(from: run.attrs[MarkdownAttribute.headingLevel]) != nil,
              end == run.nodeByteRange.upperBound,
              end < bytes.count, bytes[end] == UInt8(ascii: "\n") else {
            return end
        }

        let headingLine = lineStart(before: run.nodeByteRange.lowerBound, in: bytes)
        var scanner = MarkdownBlockPrefixScanner(slice: bytes[headingLine...])
        scanner.consumeIndentAndBars()
        guard scanner.peek() != UInt8(ascii: "#") else { return end }

        let underlineEnd = lineEnd(from: end + 1, in: bytes)
        guard isSetextUnderline(bytes[(end + 1)..<underlineEnd]) else { return end }
        return underlineEnd
    }

    static func isSetextUnderline(_ line: ArraySlice<UInt8>) -> Bool {
        var index = line.startIndex
        var indent = 0
        while index < line.endIndex, line[index] == UInt8(ascii: " "), indent < 3 {
            index += 1
            indent += 1
        }
        guard index < line.endIndex else { return false }
        let marker = line[index]
        guard marker == UInt8(ascii: "=") || marker == UInt8(ascii: "-") else { return false }
        while index < line.endIndex, line[index] == marker {
            index += 1
        }
        while index < line.endIndex,
              line[index] == UInt8(ascii: " ") || line[index] == UInt8(ascii: "\t") {
            index += 1
        }
        return index == line.endIndex
    }

    static func isFenceLine(_ slice: ArraySlice<UInt8>, requireBare: Bool) -> Bool {
        var index = slice.startIndex
        var indent = 0
        while index < slice.endIndex, slice[index] == UInt8(ascii: " "), indent < 3 {
            index += 1
            indent += 1
        }
        guard index < slice.endIndex else { return false }
        let fenceChar = slice[index]
        guard fenceChar == UInt8(ascii: "`") || fenceChar == UInt8(ascii: "~") else { return false }
        var count = 0
        while index < slice.endIndex, slice[index] == fenceChar {
            index += 1
            count += 1
        }
        guard count >= 3 else { return false }
        guard requireBare else { return true }
        return slice[index...].allSatisfy { $0 == UInt8(ascii: " ") || $0 == UInt8(ascii: "\t") }
    }

}
