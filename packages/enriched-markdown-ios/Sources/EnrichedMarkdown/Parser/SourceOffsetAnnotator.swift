import Foundation

/// Annotates a parsed AST with `srcStart`/`srcEnd` attributes — UTF-8 byte
/// ranges into the original source — without any parser involvement: text
/// nodes carry source bytes in document order, so one forward scan locates
/// each run, and containers aggregate their descendants' ranges.
///
/// Ranges cover the source bytes that produce a node's literal text; syntax
/// markers sit outside them, except that a backslash escape or entity
/// reference inside a run is included (its range then spans the escaped
/// form). Entity matches are trusted, not decoded — consumers re-validate
/// slices, so a wrong guess falls back to reconstruction. Thematic breaks
/// are located structurally (the next `---`-style line). A node whose
/// content still cannot be matched is left unannotated (cursor unmoved).
/// The attribute contract matches what a parser-side implementation would
/// emit, so downstream code is provenance-agnostic.
enum SourceOffsetAnnotator {
    static let sourceStartKey = "srcStart"
    static let sourceEndKey = "srcEnd"

    static func annotate(_ root: MarkdownASTNode, source: String) -> MarkdownASTNode {
        var scanner = Scanner(source: Array(source.utf8))
        return annotateNode(root, scanner: &scanner).node
    }

    static func sourceRange(of node: MarkdownASTNode) -> (start: Int, end: Int)? {
        guard let start = node.attribute(sourceStartKey).flatMap(Int.init),
              let end = node.attribute(sourceEndKey).flatMap(Int.init) else {
            return nil
        }
        return (start, end)
    }

    /// The node's range as the `NSValue`-wrapped byte `NSRange` the renderer
    /// puts on runs.
    static func sourceRangeValue(of node: MarkdownASTNode) -> NSValue? {
        sourceRange(of: node).map {
            NSValue(range: NSRange(location: $0.start, length: $0.end - $0.start))
        }
    }

    /// Adds the node's range to a run's attributes under
    /// `MarkdownAttribute.sourceRange`, when annotated.
    static func tagSourceRange(in attributes: inout [NSAttributedString.Key: Any], of node: MarkdownASTNode) {
        if let value = sourceRangeValue(of: node) {
            attributes[MarkdownAttribute.sourceRange] = value
        }
    }

    // MARK: - Internals

    private struct Scanner {
        let source: [UInt8]
        var cursor = 0

        /// Finds `content` at or after the cursor and advances past it; the
        /// cursor never moves on failure.
        mutating func match(_ content: String) -> (start: Int, end: Int)? {
            let needle = Array(content.utf8)
            guard !needle.isEmpty else { return nil }

            var index = cursor
            while index < source.count {
                if let end = matchFlexible(needle, at: index) {
                    cursor = end
                    return (index, end)
                }
                index += 1
            }
            return nil
        }

        /// The line of the next thematic break at or after the cursor,
        /// skipping only blank lines so the scan cannot jump over later
        /// nodes' content.
        mutating func matchThematicBreak() -> (start: Int, end: Int)? {
            var lineStart = cursor
            if lineStart > 0, source[lineStart - 1] != UInt8(ascii: "\n") {
                while lineStart < source.count, source[lineStart] != UInt8(ascii: "\n") {
                    lineStart += 1
                }
                lineStart += 1
            }

            while lineStart < source.count {
                var lineEnd = lineStart
                while lineEnd < source.count, source[lineEnd] != UInt8(ascii: "\n") {
                    lineEnd += 1
                }
                if isThematicBreakLine(source[lineStart..<lineEnd]) {
                    cursor = lineEnd
                    return (lineStart, lineEnd)
                }
                guard isBlankLine(source[lineStart..<lineEnd]) else { return nil }
                lineStart = lineEnd + 1
            }
            return nil
        }

        /// Matches `needle` at `index`, letting a source backslash escape
        /// match its bare character and an entity reference match one scalar
        /// of the needle.
        private func matchFlexible(_ needle: [UInt8], at index: Int) -> Int? {
            var sourceIndex = index
            var needleIndex = 0
            while needleIndex < needle.count {
                guard sourceIndex < source.count else { return nil }
                if source[sourceIndex] == needle[needleIndex] {
                    sourceIndex += 1
                    needleIndex += 1
                    continue
                }
                if source[sourceIndex] == UInt8(ascii: "\\"),
                   sourceIndex + 1 < source.count,
                   source[sourceIndex + 1] == needle[needleIndex],
                   isEscapablePunctuation(needle[needleIndex]) {
                    sourceIndex += 2
                    needleIndex += 1
                    continue
                }
                if let entityEnd = entityEnd(startingAt: sourceIndex),
                   let scalarLength = scalarLength(of: needle, at: needleIndex) {
                    sourceIndex = entityEnd
                    needleIndex += scalarLength
                    continue
                }
                return nil
            }
            return sourceIndex
        }

        /// One past a `&name;` / `&#123;` reference, or nil.
        private func entityEnd(startingAt index: Int) -> Int? {
            guard source[index] == UInt8(ascii: "&") else { return nil }
            var cursor = index + 1
            let limit = min(source.count, index + 48)
            while cursor < limit {
                let byte = source[cursor]
                if byte == UInt8(ascii: ";") {
                    return cursor > index + 1 ? cursor + 1 : nil
                }
                guard byte == UInt8(ascii: "#") || isAlphanumeric(byte) else { return nil }
                cursor += 1
            }
            return nil
        }

        /// Byte length of the UTF-8 scalar starting at `index`, bounds-checked.
        private func scalarLength(of needle: [UInt8], at index: Int) -> Int? {
            let length: Int
            switch needle[index] {
            case ..<0x80: length = 1
            case 0xC0...0xDF: length = 2
            case 0xE0...0xEF: length = 3
            case 0xF0...0xF7: length = 4
            default: return nil
            }
            return index + length <= needle.count ? length : nil
        }

        private func isEscapablePunctuation(_ byte: UInt8) -> Bool {
            (0x21...0x2F).contains(byte)
                || (0x3A...0x40).contains(byte)
                || (0x5B...0x60).contains(byte)
                || (0x7B...0x7E).contains(byte)
        }

        private func isAlphanumeric(_ byte: UInt8) -> Bool {
            (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                || (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte)
                || (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(byte)
        }

        /// Optionally indented/quoted line of 3+ interleaved `-`/`*`/`_`.
        private func isThematicBreakLine(_ line: ArraySlice<UInt8>) -> Bool {
            var index = line.startIndex
            while index < line.endIndex,
                  line[index] == UInt8(ascii: " ") || line[index] == UInt8(ascii: "\t")
                    || line[index] == UInt8(ascii: ">") {
                index += 1
            }
            guard index < line.endIndex else { return false }
            let marker = line[index]
            guard marker == UInt8(ascii: "-") || marker == UInt8(ascii: "*")
                    || marker == UInt8(ascii: "_") else { return false }
            var count = 0
            while index < line.endIndex {
                let byte = line[index]
                if byte == marker {
                    count += 1
                } else if byte != UInt8(ascii: " ") && byte != UInt8(ascii: "\t") {
                    return false
                }
                index += 1
            }
            return count >= 3
        }

        private func isBlankLine(_ line: ArraySlice<UInt8>) -> Bool {
            line.allSatisfy { $0 == UInt8(ascii: " ") || $0 == UInt8(ascii: "\t") }
        }
    }

    private static func annotateNode(
        _ node: MarkdownASTNode,
        scanner: inout Scanner
    ) -> (node: MarkdownASTNode, range: (start: Int, end: Int)?) {
        if node.type == .text {
            guard let range = scanner.match(node.content) else { return (node, nil) }
            return (annotated(node, children: node.children, range: range), range)
        }
        if node.type == .thematicBreak {
            guard let range = scanner.matchThematicBreak() else { return (node, nil) }
            return (annotated(node, children: node.children, range: range), range)
        }

        var children: [MarkdownASTNode] = []
        children.reserveCapacity(node.children.count)
        var start: Int?
        var end: Int?
        for child in node.children {
            let result = annotateNode(child, scanner: &scanner)
            children.append(result.node)
            guard let range = result.range else { continue }
            // The scanner only moves forward, so child ranges are ordered.
            if start == nil {
                start = range.start
            }
            end = range.end
        }

        guard let start, let end else {
            return (annotated(node, children: children, range: nil), nil)
        }
        return (annotated(node, children: children, range: (start, end)), (start, end))
    }

    private static func annotated(
        _ node: MarkdownASTNode,
        children: [MarkdownASTNode],
        range: (start: Int, end: Int)?
    ) -> MarkdownASTNode {
        var attributes = node.attributes
        if let range {
            attributes[sourceStartKey] = String(range.start)
            attributes[sourceEndKey] = String(range.end)
        }
        return MarkdownASTNode(
            type: node.type,
            content: node.content,
            attributes: attributes,
            children: children
        )
    }
}
