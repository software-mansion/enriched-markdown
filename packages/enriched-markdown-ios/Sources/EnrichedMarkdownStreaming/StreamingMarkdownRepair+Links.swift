import Foundation

extension StreamingMarkdownRepair {
    // MARK: - Truncation

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

    static func healingTrailingLinks(_ text: [Unicode.Scalar]) -> [Unicode.Scalar] {
        var current = text
        for _ in 0..<32 {
            let next = healingTrailingLink(current)
            if next == current {
                return next
            }
            current = next
        }
        return current
    }

    private static func healingTrailingLink(_ text: [Unicode.Scalar]) -> [Unicode.Scalar] {
        let spans = SpanScan(text)

        if let paren = lastIndex(of: "]", then: "(", in: text), spans.isProse(paren),
           !text[(paren + 2)...].contains(")"),
           let open = matchingOpeningBracket(in: text, closingAt: paren), spans.isProse(open) {
            return unwrapping(text, open: open, close: paren)
        }

        var index = text.lastIndex(of: "[")
        while let open = index {
            defer { index = text[..<open].lastIndex(of: "[") }
            guard spans.isProse(open), !isEscaped(text, open) else { continue }
            guard matchingClosingBracket(in: text, openingAt: open) == nil else { continue }
            if open > 0, text[open - 1] == "!" {
                return Array(text[..<(open - 1)])
            }
            let first = firstIncompleteBracket(in: text, spans: spans) ?? open
            return Array(text[..<first]) + Array(text[(first + 1)...])
        }

        if text.last == "]", spans.isProse(text.count - 1),
           let open = matchingOpeningBracket(in: text, closingAt: text.count - 1),
           spans.isProse(open), !isEscaped(text, open), !isTaskCheckbox(text, open: open),
           !isAdmonitionMarker(text, open: open) {
            return unwrapping(text, open: open, close: text.count - 1)
        }
        return text
    }

    private static func unwrapping(_ text: [Unicode.Scalar], open: Int, close: Int) -> [Unicode.Scalar] {
        if open > 0, text[open - 1] == "!" {
            return Array(text[..<(open - 1)])
        }
        return Array(text[..<open]) + Array(text[(open + 1)..<close])
    }

    private static func firstIncompleteBracket(in text: [Unicode.Scalar], spans: SpanScan) -> Int? {
        var index = 0
        while index < text.count {
            defer { index += 1 }
            guard text[index] == "[", spans.isProse(index), !isEscaped(text, index) else { continue }
            if index > 0, text[index - 1] == "!" {
                continue
            }
            guard let close = matchingClosingBracket(in: text, openingAt: index) else {
                return index
            }
            if close + 1 < text.count, text[close + 1] == "(",
               let urlEnd = text[(close + 2)...].firstIndex(of: ")") {
                index = urlEnd
            }
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

    private static func matchingClosingBracket(in text: [Unicode.Scalar], openingAt open: Int) -> Int? {
        var depth = 1
        for index in (open + 1)..<max(open + 1, text.count) {
            if text[index] == "[" {
                depth += 1
            } else if text[index] == "]" {
                depth -= 1
                if depth == 0 {
                    return index
                }
            }
        }
        return nil
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
}
