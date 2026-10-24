import EnrichedMarkdown
import EnrichedMarkdownRepair
import Foundation

enum StreamingMarkdownRepair {
    static func repair(_ markdown: String, options: MarkdownParsingOptions) -> String {
        var text = Array(markdown.unicodeScalars)
        if let fence = FenceScan.openFence(in: text) {
            return string(removingPartialCloser(of: fence, from: text))
        }

        text = removingTrailingMarkerLine(text)
        let scopeStart = inlineScopeStart(in: text)
        var scopeEnd = text.count
        while scopeEnd > scopeStart, isWhitespace(text[scopeEnd - 1]) {
            scopeEnd -= 1
        }

        var scope = Array(text[scopeStart..<scopeEnd])
        if options.latexMathEnabled {
            scope = truncatingUnclosedMath(scope)
        }
        scope = unwrappingTrailingLabel(scope)
        scope = droppingTrailingOpeners(scope)
        while let last = scope.last, isWhitespace(last) {
            scope.removeLast()
        }

        return closingOpenSyntax(in: string(text[..<scopeStart] + scope), highlight: options.highlight)
            + string(text[scopeEnd...])
    }

    private static func closingOpenSyntax(in markdown: String, highlight: Bool) -> String {
        guard let repaired = em_repair_inline_markdown(markdown, highlight ? 1 : 0) else { return markdown }
        defer { em_repair_release(repaired) }
        return String(cString: repaired)
    }

    private static func string<S: Sequence>(_ scalars: S) -> String where S.Element == Unicode.Scalar {
        String(String.UnicodeScalarView(scalars))
    }

    // MARK: - Block-level trimming

    static func removingTrailingMarkerLine(_ text: [Unicode.Scalar]) -> [Unicode.Scalar] {
        let lineStart = (text.lastIndex(of: "\n") ?? -1) + 1
        let line = text[lineStart...]
        guard line.contains(where: { !isWhitespace($0) }) else { return text }

        let contentStart = skippingQuoteMarkers(in: text, from: lineStart)
        var remainder = Array(text[contentStart...].drop(while: isWhitespace))
        while let last = remainder.last, isWhitespace(last) {
            remainder.removeLast()
        }
        let isMarkerOnly: Bool
        if remainder.isEmpty {
            isMarkerOnly = true
        } else if let marker = remainder.first, "#=-`~".unicodeScalars.contains(marker),
                  remainder.allSatisfy({ $0 == marker }) {
            let limit = marker == "#" ? 6 : 2
            isMarkerOnly = remainder.count <= limit
        } else if contentStart > lineStart, remainder.starts(with: "[!".unicodeScalars), !remainder.contains("]") {
            isMarkerOnly = true
        } else if let length = listMarkerLength(remainder, at: 0) {
            let rest = remainder[length...].drop(while: isWhitespace)
            isMarkerOnly = rest.isEmpty || isOpenCheckbox(rest)
        } else {
            isMarkerOnly = false
        }
        return isMarkerOnly ? Array(text[..<lineStart]) : text
    }

    private static func isOpenCheckbox(_ rest: ArraySlice<Unicode.Scalar>) -> Bool {
        guard rest.first == "[", rest.count <= 2 else { return false }
        return rest.count == 1 || " xX".unicodeScalars.contains(rest[rest.startIndex + 1])
    }

    private static func removingPartialCloser(of fence: FenceScan.OpenFence, from text: [Unicode.Scalar]) -> [Unicode.Scalar] {
        let lineStart = (text.lastIndex(of: "\n") ?? -1) + 1
        let run = text[skippingQuoteMarkers(in: text, from: lineStart)...].drop(while: { $0 == " " })
        guard !run.isEmpty, run.count < fence.length, run.allSatisfy({ $0 == fence.character }) else { return text }
        return Array(text[..<lineStart])
    }

    static func inlineScopeStart(in text: [Unicode.Scalar]) -> Int {
        let lineStarts = [0] + text.indices.filter { text[$0] == "\n" }.map { $0 + 1 }
        var line = lineStarts.count - 1

        let lastLineContent = skippingQuoteMarkers(in: text, from: lineStarts[line])
        if lastLineContent < text.count, text[lastLineContent] == "|" {
            let spans = SpanScan(text, from: lineStarts[line])
            var cellStart = lineStarts[line]
            for index in lineStarts[line]..<text.count
            where text[index] == "|" && spans.isProse(index) && !isEscaped(text, index) {
                cellStart = index + 1
            }
            return cellStart
        }

        while line > 0 {
            let current = lineStarts[line]
            let previous = lineStarts[line - 1]
            if startsBlock(text, lineStart: current)
                || isBlankLine(text, lineStart: previous)
                || endsBlock(text, lineStart: previous) {
                break
            }
            line -= 1
        }
        return lineStarts[line]
    }

    private static func startsBlock(_ text: [Unicode.Scalar], lineStart: Int) -> Bool {
        guard let index = lineContentStart(text, lineStart: lineStart) else { return false }
        return listMarkerEnd(text, at: index) != nil || text[index] == "|" || startsHeadingOrFence(text, at: index)
    }

    private static func endsBlock(_ text: [Unicode.Scalar], lineStart: Int) -> Bool {
        guard let index = lineContentStart(text, lineStart: lineStart) else { return false }
        return text[index] == "|" || startsHeadingOrFence(text, at: index)
            || isHorizontalRule(text, markerIndex: index, marker: text[index])
    }

    private static func lineContentStart(_ text: [Unicode.Scalar], lineStart: Int) -> Int? {
        var index = skippingQuoteMarkers(in: text, from: lineStart)
        while index < text.count, text[index] == " " || text[index] == "\t" {
            index += 1
        }
        return index < text.count ? index : nil
    }

    private static func startsHeadingOrFence(_ text: [Unicode.Scalar], at index: Int) -> Bool {
        let marker = text[index]
        guard marker == "#" || marker == "`" || marker == "~" else { return false }
        var end = index
        while end < text.count, text[end] == marker {
            end += 1
        }
        if marker == "#" {
            return end - index <= 6 && (end == text.count || isWhitespace(text[end]))
        }
        return end - index >= 3
    }

    private static func isBlankLine(_ text: [Unicode.Scalar], lineStart: Int) -> Bool {
        var index = skippingQuoteMarkers(in: text, from: lineStart)
        while index < text.count, text[index] != "\n" {
            if !isWhitespace(text[index]) {
                return false
            }
            index += 1
        }
        return true
    }

    static func skippingQuoteMarkers(in text: [Unicode.Scalar], from start: Int) -> Int {
        var index = start
        while true {
            var probe = index
            while probe < text.count, text[probe] == " " {
                probe += 1
            }
            guard probe < text.count, text[probe] == ">" else { return index }
            index = probe + 1
        }
    }

    static func listMarkerEnd(_ text: [Unicode.Scalar], at index: Int) -> Int? {
        guard let length = listMarkerLength(text, at: index) else { return nil }
        let end = index + length
        if end == text.count || text[end] == "\n" {
            return end
        }
        return text[end] == " " || text[end] == "\t" ? end + 1 : nil
    }

    private static func listMarkerLength(_ text: [Unicode.Scalar], at index: Int) -> Int? {
        guard index < text.count else { return nil }
        return "-*+".unicodeScalars.contains(text[index]) ? 1 : orderedListMarkerLength(text, at: index)
    }

    private static func orderedListMarkerLength(_ text: [Unicode.Scalar], at index: Int) -> Int? {
        var end = index
        while end < text.count, end - index < 9, ("0"..."9").contains(text[end]) {
            end += 1
        }
        guard end > index, end < text.count, text[end] == "." || text[end] == ")" else { return nil }
        return end + 1 - index
    }
}

extension StreamingMarkdownRepair {
    // MARK: - Inline trimming

    static func truncatingUnclosedMath(_ text: [Unicode.Scalar]) -> [Unicode.Scalar] {
        let spans = SpanScan(text)
        var openers: [(index: Int, length: Int)] = []
        var index = 0
        while index < text.count {
            guard text[index] == "$", spans.isProse(index), !isEscaped(text, index) else {
                index += 1
                continue
            }
            var end = index
            while end < text.count, text[end] == "$" {
                end += 1
            }
            let length = end - index
            defer { index = end }
            guard length <= 2 else { continue }

            let canOpen = index == 0 || text[index - 1] == "\n"
                || isWhitespace(text[index - 1]) || isPunctuation(text[index - 1])
            let canClose = end == text.count || text[end] == "\n"
                || isWhitespace(text[end]) || isPunctuation(text[end])
            if canClose, let top = openers.last, top.length == length {
                openers.removeAll()
                continue
            }
            if canOpen {
                openers.append((index, length))
            }
        }

        guard let open = openers.last else { return text }
        if open.length == 1 {
            let next = open.index + 1
            guard next < text.count, !isWhitespace(text[next]), !("0"..."9").contains(text[next]) else {
                return text
            }
        }
        return Array(text[..<open.index])
    }

    static func unwrappingTrailingLabel(_ text: [Unicode.Scalar]) -> [Unicode.Scalar] {
        let close = text.count - 1
        guard close > 0, text[close] == "]", !isEscaped(text, close),
              let open = matchingOpeningBracket(in: text, closingAt: close),
              !isEscaped(text, open), !isTaskCheckbox(text, open: open), !isAdmonitionMarker(text, open: open)
        else { return text }
        let spans = SpanScan(text)
        guard spans.isProse(open), spans.isProse(close) else { return text }
        if open > 0, text[open - 1] == "!" {
            return Array(text[..<(open - 1)])
        }
        return Array(text[..<open]) + Array(text[(open + 1)..<close])
    }

    private static func matchingOpeningBracket(in text: [Unicode.Scalar], closingAt close: Int) -> Int? {
        var depth = 1
        var index = close - 1
        while index >= 0 {
            if text[index] == "]" {
                depth += 1
            } else if text[index] == "[" {
                depth -= 1
                if depth == 0 {
                    return index
                }
            }
            index -= 1
        }
        return nil
    }

    private static func isTaskCheckbox(_ text: [Unicode.Scalar], open: Int) -> Bool {
        guard text.count - open == 3, " xX".unicodeScalars.contains(text[open + 1]) else { return false }
        let lineStart = (text[..<open].lastIndex(of: "\n") ?? -1) + 1
        var index = skippingQuoteMarkers(in: text, from: lineStart)
        while index < open, text[index] == " " {
            index += 1
        }
        guard index < open, let markerEnd = listMarkerEnd(text, at: index) else { return false }
        return text[markerEnd..<open].allSatisfy(isWhitespace)
    }

    private static func isAdmonitionMarker(_ text: [Unicode.Scalar], open: Int) -> Bool {
        guard open + 1 < text.count, text[open + 1] == "!" else { return false }
        let lineStart = (text[..<open].lastIndex(of: "\n") ?? -1) + 1
        let content = skippingQuoteMarkers(in: text, from: lineStart)
        return content > lineStart && text[content..<open].allSatisfy { $0 == " " }
    }

    static func droppingTrailingOpeners(_ text: [Unicode.Scalar]) -> [Unicode.Scalar] {
        var start = text.count
        while start > 0, "*_~`=|".unicodeScalars.contains(text[start - 1]) {
            start -= 1
        }
        guard start < text.count, start == 0 || isWhitespace(text[start - 1]), !isFenceLine(text, from: start) else { return text }
        let spans = SpanScan(text)
        guard spans.isProse(start) || spans.openSpan?.start == start, !isEscaped(text, start) else { return text }
        return Array(text[..<start])
    }

    private static func isFenceLine(_ text: [Unicode.Scalar], from start: Int) -> Bool {
        let run = text[start...]
        guard run.count >= 3, let marker = run.first, marker == "`" || marker == "~",
              run.allSatisfy({ $0 == marker })
        else { return false }
        let lineStart = (text[..<start].lastIndex(of: "\n") ?? -1) + 1
        return text[lineStart..<start].allSatisfy { $0 == " " || $0 == "\t" || $0 == ">" }
    }

    // MARK: - Character classes

    static func isWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        scalar == " " || scalar == "\t" || scalar == "\n" || scalar == "\r"
    }

    static func isPunctuation(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation,
             .mathSymbol, .currencySymbol, .modifierSymbol, .otherSymbol:
            return true
        default:
            return false
        }
    }

    static func isHorizontalRule(_ text: [Unicode.Scalar], markerIndex: Int, marker: Unicode.Scalar) -> Bool {
        let lineStart = (text[..<markerIndex].lastIndex(of: "\n") ?? -1) + 1
        let lineEnd = text[markerIndex...].firstIndex(of: "\n") ?? text.count
        var count = 0
        for scalar in text[lineStart..<lineEnd] {
            if scalar == marker {
                count += 1
            } else if scalar != " " && scalar != "\t" {
                return false
            }
        }
        return count >= 3
    }

    static func isEscaped(_ text: [Unicode.Scalar], _ index: Int) -> Bool {
        var backslashes = 0
        var probe = index - 1
        while probe >= 0, text[probe] == "\\" {
            backslashes += 1
            probe -= 1
        }
        return backslashes % 2 == 1
    }
}
