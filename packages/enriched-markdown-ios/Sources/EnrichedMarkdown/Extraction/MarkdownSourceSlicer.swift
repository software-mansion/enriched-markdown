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

    static let invisibleScalars = CharacterSet(charactersIn: " \t\n\r\u{200B}\u{2028}")

    static func isInvisible(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy { invisibleScalars.contains($0) }
    }

    // MARK: - Inline marker snapping

    enum EdgeTrait: CaseIterable {
        case inlineCode
        case strikethrough
        case underline
        case emphasis
        case strong
        case link

        var key: NSAttributedString.Key {
            switch self {
            case .inlineCode: return MarkdownAttribute.inlineCode
            case .strikethrough: return .strikethroughStyle
            case .underline: return .underlineStyle
            case .emphasis: return MarkdownAttribute.emphasis
            case .strong: return MarkdownAttribute.strong
            case .link: return .link
            }
        }

        func isActive(in attrs: [NSAttributedString.Key: Any]) -> Bool {
            switch self {
            case .inlineCode:
                return MarkdownAttributeValue.boolValue(from: attrs[key]) && attrs[.link] == nil
            case .strikethrough:
                return (MarkdownAttributeValue.intValue(from: attrs[key]) ?? 0) != 0
            case .underline:
                return (MarkdownAttributeValue.intValue(from: attrs[key]) ?? 0) != 0 && attrs[.link] == nil
            case .emphasis, .strong:
                return MarkdownAttributeValue.boolValue(from: attrs[key])
            case .link:
                return attrs[key] != nil
            }
        }

        var openingMarkers: [String] {
            switch self {
            case .strong: return ["**", "__"]
            case .emphasis: return ["*", "_"]
            case .strikethrough: return ["~~"]
            case .underline: return ["<u>"]
            case .inlineCode, .link: return []
            }
        }

        var closingMarkers: [String] {
            switch self {
            case .underline: return ["</u>"]
            case .inlineCode, .link: return []
            default: return openingMarkers
            }
        }
    }

    /// Traits whose full rendered span lies inside the selection — only then
    /// are BOTH of the span's marker sides selected (adjacent to an edge or
    /// interior to the byte union), so consuming one edge keeps the slice
    /// balanced.
    static func coveredTraits(
        of run: MappedRun,
        at location: Int,
        selection: NSRange,
        in attributedText: NSAttributedString
    ) -> [EdgeTrait] {
        let fullRange = NSRange(location: 0, length: attributedText.length)
        return EdgeTrait.allCases.filter { trait in
            guard trait.isActive(in: run.attrs) else { return false }
            var span = NSRange()
            guard attributedText.attribute(
                trait.key, at: location, longestEffectiveRange: &span, in: fullRange
            ) != nil else { return false }
            return NSIntersectionRange(span, selection) == span
        }
    }

    /// Expands `start` backward over the opening markers of fully-selected
    /// spans. Returns nil when a covered link's `[` is missing (reference
    /// links, autolinks) — a plain slice would silently drop the link, so
    /// the caller must fall back.
    static func snapStart(
        _ start: Int,
        run: MappedRun,
        selection: NSRange,
        in attributedText: NSAttributedString,
        bytes: [UInt8]
    ) -> Int? {
        guard start == run.nodeByteRange.lowerBound else { return start }
        if run.attrs[.attachment] is MarkdownImageAttachment {
            // The mapped range covers only the alt text; a missing "![" (an
            // unmatchable image form) must abort so the image is not lost.
            return matchBackward("![", in: bytes, before: start)
        }
        if run.attrs[.attachment] != nil {
            return start
        }

        var result = start
        var remaining = coveredTraits(of: run, at: run.runRange.location, selection: selection, in: attributedText)
        var progressed = true
        while progressed {
            progressed = false
            for (index, trait) in remaining.enumerated() {
                let consumedTo: Int?
                switch trait {
                case .link:
                    consumedTo = matchBackward("[", in: bytes, before: result)
                case .inlineCode:
                    consumedTo = consumeBackticksBackward(in: bytes, before: result)
                default:
                    consumedTo = trait.openingMarkers
                        .compactMap { matchBackward($0, in: bytes, before: result) }
                        .first
                }
                if let consumedTo {
                    result = consumedTo
                    remaining.remove(at: index)
                    progressed = true
                    break
                }
                if trait == .link {
                    return nil
                }
            }
        }
        return result
    }

    /// Forward counterpart of `snapStart`; a covered link consumes its
    /// `](destination)` bytes or aborts.
    static func snapEnd(
        _ end: Int,
        run: MappedRun,
        selection: NSRange,
        in attributedText: NSAttributedString,
        bytes: [UInt8]
    ) -> Int? {
        guard end == run.nodeByteRange.upperBound else { return end }
        if run.attrs[.attachment] is MarkdownImageAttachment {
            return consumeLinkSuffix(in: bytes, from: end)
        }
        if run.attrs[.attachment] != nil {
            return end
        }

        var result = end
        var remaining = coveredTraits(of: run, at: run.runRange.location, selection: selection, in: attributedText)
        var progressed = true
        while progressed {
            progressed = false
            for (index, trait) in remaining.enumerated() {
                let consumedTo: Int?
                switch trait {
                case .link:
                    consumedTo = consumeLinkSuffix(in: bytes, from: result)
                case .inlineCode:
                    consumedTo = consumeBackticksForward(in: bytes, from: result)
                default:
                    consumedTo = trait.closingMarkers
                        .compactMap { matchForward($0, in: bytes, at: result) }
                        .first
                }
                if let consumedTo {
                    result = consumedTo
                    remaining.remove(at: index)
                    progressed = true
                    break
                }
                if trait == .link {
                    return nil
                }
            }
        }
        return result
    }

    static func matchBackward(_ marker: String, in bytes: [UInt8], before index: Int) -> Int? {
        let markerBytes = Array(marker.utf8)
        let start = index - markerBytes.count
        guard start >= 0, Array(bytes[start..<index]) == markerBytes else { return nil }
        return start
    }

    static func matchForward(_ marker: String, in bytes: [UInt8], at index: Int) -> Int? {
        let markerBytes = Array(marker.utf8)
        let end = index + markerBytes.count
        guard end <= bytes.count, Array(bytes[index..<end]) == markerBytes else { return nil }
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

    /// Extends `start` to the start of its line when every byte in between
    /// is block-prefix syntax (indentation, blockquote bars, a list marker
    /// with optional task box, heading hashes) — the selection then starts
    /// the line's text, so its markers are visually included.
    static func expandBlockPrefix(from start: Int, bytes: [UInt8]) -> Int {
        var lineStart = start
        while lineStart > 0, bytes[lineStart - 1] != UInt8(ascii: "\n") {
            lineStart -= 1
        }
        guard lineStart < start, isBlockPrefix(bytes[lineStart..<start]) else { return start }
        return lineStart
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
        let lineEnd = start - 1
        var lineStart = lineEnd
        while lineStart > 0, bytes[lineStart - 1] != UInt8(ascii: "\n") {
            lineStart -= 1
        }
        guard isFenceLine(bytes[lineStart..<lineEnd], requireBare: false) else { return start }
        return lineStart
    }

    /// Code content includes its trailing newline, so a fully-selected block
    /// ends where the closing fence's line begins.
    static func expandClosingFence(from end: Int, run: MappedRun, bytes: [UInt8]) -> Int {
        guard isCodeBlockRun(run), end == run.nodeByteRange.upperBound else { return end }
        var lineEnd = end
        while lineEnd < bytes.count, bytes[lineEnd] != UInt8(ascii: "\n") {
            lineEnd += 1
        }
        guard isFenceLine(bytes[end..<lineEnd], requireBare: true) else { return end }
        return lineEnd
    }

    // MARK: - Tables and setext headings

    /// A table's aggregated range starts at the first header cell's text and
    /// ends at the last cell's text; the row pipes live on the same lines.
    static func expandTableStart(from start: Int, run: MappedRun, bytes: [UInt8]) -> Int {
        guard run.attrs[.attachment] is TableAttachment else { return start }
        var lineStart = start
        while lineStart > 0, bytes[lineStart - 1] != UInt8(ascii: "\n") {
            lineStart -= 1
        }
        return lineStart
    }

    static func expandTableEnd(from end: Int, run: MappedRun, bytes: [UInt8]) -> Int {
        guard run.attrs[.attachment] is TableAttachment else { return end }
        var lineEnd = end
        while lineEnd < bytes.count, bytes[lineEnd] != UInt8(ascii: "\n") {
            lineEnd += 1
        }
        return lineEnd
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

        var headingLineStart = run.nodeByteRange.lowerBound
        while headingLineStart > 0, bytes[headingLineStart - 1] != UInt8(ascii: "\n") {
            headingLineStart -= 1
        }
        var significant = headingLineStart
        while significant < bytes.count,
              bytes[significant] == UInt8(ascii: " ") || bytes[significant] == UInt8(ascii: "\t")
                || bytes[significant] == UInt8(ascii: ">") {
            significant += 1
        }
        guard significant < bytes.count, bytes[significant] != UInt8(ascii: "#") else { return end }

        let lineStart = end + 1
        var lineEnd = lineStart
        while lineEnd < bytes.count, bytes[lineEnd] != UInt8(ascii: "\n") {
            lineEnd += 1
        }
        guard isSetextUnderline(bytes[lineStart..<lineEnd]) else { return end }
        return lineEnd
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
