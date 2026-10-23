import Foundation

struct SpanScan {
    private var prose: [Bool]
    private(set) var openSpan: (start: Int, runLength: Int)?

    init(_ text: [Unicode.Scalar], from start: Int = 0) {
        prose = Array(repeating: true, count: text.count)
        var spanStart = -1
        var spanRunLength = 0
        var index = start

        while index < text.count {
            if spanStart < 0 {
                guard let opener = Self.nextOpener(in: text, from: index) else { break }
                let end = Self.runEnd(in: text, from: opener)
                spanStart = opener
                spanRunLength = end - opener
                index = end
                continue
            }
            if text[index] == "\n", Self.isParagraphBreak(text, at: index) {
                spanStart = -1
                index += 1
                continue
            }
            guard text[index] == "`" else {
                index += 1
                continue
            }
            let end = Self.runEnd(in: text, from: index)
            if end - index == spanRunLength {
                for position in spanStart..<end {
                    prose[position] = false
                }
                spanStart = -1
            }
            index = end
        }

        if spanStart >= 0 {
            for position in spanStart..<text.count {
                prose[position] = false
            }
            openSpan = (spanStart, spanRunLength)
        }
    }

    func isProse(_ index: Int) -> Bool {
        guard index < prose.count else { return openSpan == nil }
        return index < 0 || prose[index]
    }

    private static func nextOpener(in text: [Unicode.Scalar], from start: Int) -> Int? {
        var index = start
        while index < text.count {
            if text[index] == "`", !StreamingMarkdownRepair.isEscaped(text, index) {
                return index
            }
            index += 1
        }
        return nil
    }

    private static func runEnd(in text: [Unicode.Scalar], from start: Int) -> Int {
        var end = start + 1
        while end < text.count, text[end] == "`" {
            end += 1
        }
        return end
    }

    private static func isParagraphBreak(_ text: [Unicode.Scalar], at newline: Int) -> Bool {
        var index = newline + 1
        while index < text.count, text[index] == " " || text[index] == "\t" || text[index] == "\r" {
            index += 1
        }
        return index < text.count && text[index] == "\n"
    }
}

enum FenceScan {
    struct OpenFence {
        let character: Unicode.Scalar
        let length: Int
        let quoteDepth: Int
    }

    static func openFence(in text: [Unicode.Scalar]) -> OpenFence? {
        var open: OpenFence?
        var lineStart = 0
        while lineStart <= text.count {
            let lineEnd = text[lineStart...].firstIndex(of: "\n") ?? text.count
            if let fence = open {
                if let contentStart = skippingQuotes(text, lineStart, lineEnd, depth: fence.quoteDepth) {
                    if isCloser(text, contentStart, lineEnd, fence) {
                        open = nil
                        lineStart = lineEnd + 1
                        continue
                    }
                } else {
                    open = nil
                }
            }
            if open == nil {
                open = opener(text, lineStart, lineEnd)
            }
            lineStart = lineEnd + 1
        }
        return open
    }

    private static func opener(_ text: [Unicode.Scalar], _ lineStart: Int, _ lineEnd: Int) -> OpenFence? {
        guard let (index, quoteDepth) = contentStart(text, lineStart, lineEnd) else { return nil }
        let character = text[index]
        guard character == "`" || character == "~" else { return nil }
        var end = index
        while end < lineEnd, text[end] == character {
            end += 1
        }
        guard end - index >= 3 else { return nil }
        if character == "`", text[end..<lineEnd].contains("`") {
            return nil
        }
        return OpenFence(character: character, length: end - index, quoteDepth: quoteDepth)
    }

    private static func contentStart(_ text: [Unicode.Scalar], _ lineStart: Int, _ lineEnd: Int) -> (Int, Int)? {
        var index = lineStart
        var quoteDepth = 0
        while true {
            while index < lineEnd, text[index] == " " {
                index += 1
            }
            guard index < lineEnd else { return nil }
            if text[index] == ">" {
                quoteDepth += 1
                index += 1
            } else if let markerEnd = StreamingMarkdownRepair.listMarkerEnd(text, at: index) {
                index = markerEnd
            } else {
                return (index, quoteDepth)
            }
        }
    }

    private static func skippingQuotes(_ text: [Unicode.Scalar], _ lineStart: Int, _ lineEnd: Int, depth: Int) -> Int? {
        var index = lineStart
        for _ in 0..<depth {
            while index < lineEnd, text[index] == " " {
                index += 1
            }
            guard index < lineEnd, text[index] == ">" else { return nil }
            index += 1
            if index < lineEnd, text[index] == " " {
                index += 1
            }
        }
        return index
    }

    private static func isCloser(_ text: [Unicode.Scalar], _ start: Int, _ lineEnd: Int, _ fence: OpenFence) -> Bool {
        var index = start
        while index < lineEnd, text[index] == " " {
            index += 1
        }
        var run = 0
        while index < lineEnd, text[index] == fence.character {
            run += 1
            index += 1
        }
        guard run >= fence.length else { return false }
        return text[index..<lineEnd].allSatisfy { $0 == " " || $0 == "\t" || $0 == "\r" }
    }
}

struct InlineText {
    struct Match {
        let marker: Int
        let content: Range<Int>
    }

    let scalars: [Unicode.Scalar]
    let spans: SpanScan
    private let mathMask: [Bool]
    private let linkURLMask: [Bool]

    init(_ scalars: [Unicode.Scalar], latexMath: Bool) {
        self.scalars = scalars
        self.spans = SpanScan(scalars)
        self.mathMask = latexMath ? Self.buildMathMask(scalars, spans: spans) : []
        self.linkURLMask = Self.buildLinkURLMask(scalars, spans: spans)
    }

    func isProse(_ index: Int) -> Bool {
        spans.isProse(index)
    }

    func inMath(_ index: Int) -> Bool {
        index >= 0 && index < mathMask.count && mathMask[index]
    }

    func inLinkURL(_ index: Int) -> Bool {
        index >= 0 && index < linkURLMask.count && linkURLMask[index]
    }

    private func character(at index: Int) -> Unicode.Scalar? {
        index >= 0 && index < scalars.count ? scalars[index] : nil
    }

    private func isWordCharacter(at index: Int) -> Bool {
        character(at: index).map(StreamingMarkdownRepair.isWordCharacter) ?? false
    }

    private func isWhitespaceOrEdge(at index: Int) -> Bool {
        character(at: index).map(StreamingMarkdownRepair.isWhitespace) ?? true
    }

    func trailingRun(of marker: Unicode.Scalar, length: Int) -> Match? {
        var contentStart = scalars.count
        while contentStart > 0, scalars[contentStart - 1] != marker {
            contentStart -= 1
        }
        let markerStart = contentStart - length
        guard markerStart >= 0, scalars[markerStart..<contentStart].allSatisfy({ $0 == marker }) else {
            return nil
        }
        return Match(marker: markerStart, content: contentStart..<scalars.count)
    }

    func halfCompleteRun(of marker: Unicode.Scalar) -> Match? {
        guard scalars.last == marker else { return nil }
        let end = scalars.count - 1
        var contentStart = end
        while contentStart > 0, scalars[contentStart - 1] != marker {
            contentStart -= 1
        }
        guard contentStart < end, contentStart >= 2,
              scalars[contentStart - 2] == marker, scalars[contentStart - 1] == marker
        else { return nil }
        return Match(marker: contentStart - 2, content: contentStart..<end)
    }

    func countDoublePairs(of marker: Unicode.Scalar) -> Int {
        doublePairs(of: marker).count
    }

    func doublePairs(of marker: Unicode.Scalar) -> [Int] {
        var pairs: [Int] = []
        var index = 0
        while index + 1 < scalars.count {
            if scalars[index] == marker, scalars[index + 1] == marker, isProse(index) {
                pairs.append(index)
                index += 2
            } else {
                index += 1
            }
        }
        return pairs
    }

    func countTripleAsterisks() -> Int {
        var count = 0
        var run = 0
        for index in 0...scalars.count {
            if index < scalars.count, scalars[index] == "*", isProse(index) {
                run += 1
            } else {
                count += run / 3
                run = 0
            }
        }
        return count
    }

    func countSingleAsterisks() -> Int {
        var count = 0
        var inWordChain = false
        for index in scalars.indices {
            guard scalars[index] == "*", isProse(index) else {
                if !isWordCharacter(at: index) {
                    inWordChain = false
                }
                continue
            }
            guard !skipsAsterisk(at: index) else { continue }

            let isWordInternal = isWordCharacter(at: index - 1) && isWordCharacter(at: index + 1)
            let canOpen = !isWhitespaceOrEdge(at: index + 1)
            let canClose = !isWhitespaceOrEdge(at: index - 1)
            if isWordInternal, count % 2 == 0, !inWordChain {
                continue
            }
            if (canClose && count % 2 == 1) || canOpen {
                count += 1
                inWordChain = isWordInternal
            }
        }
        return count
    }

    private func skipsAsterisk(at index: Int) -> Bool {
        let previous = character(at: index - 1)
        let next = character(at: index + 1)
        if previous == "\\" || inMath(index) {
            return true
        }
        if previous != "*", next == "*" {
            return character(at: index + 2) != "*"
        }
        if previous == "*" {
            return true
        }
        return isWhitespaceOrEdge(at: index - 1) && isWhitespaceOrEdge(at: index + 1)
    }

    func firstSingleAsteriskIndex() -> Int? {
        scalars.indices.first { index in
            guard scalars[index] == "*", isProse(index),
                  character(at: index - 1) != "*", character(at: index + 1) != "*",
                  character(at: index - 1) != "\\", !inMath(index)
            else { return false }
            if isWordCharacter(at: index - 1), isWordCharacter(at: index + 1) {
                return false
            }
            return !isWhitespaceOrEdge(at: index + 1)
        }
    }

    private func skipsUnderscore(at index: Int) -> Bool {
        if character(at: index - 1) == "\\" || inMath(index) || inLinkURL(index) {
            return true
        }
        if character(at: index - 1) == "_" || character(at: index + 1) == "_" {
            return true
        }
        return isWordCharacter(at: index - 1) && isWordCharacter(at: index + 1)
    }

    func countSingleUnderscores() -> Int {
        scalars.indices.filter { scalars[$0] == "_" && isProse($0) && !skipsUnderscore(at: $0) }.count
    }

    func firstSingleUnderscoreIndex() -> Int? {
        scalars.indices.first { scalars[$0] == "_" && isProse($0) && !skipsUnderscore(at: $0) }
    }

    func hasUnmatchedDoubleUnderscore() -> Bool {
        var unmatched = false
        var index = 0
        while index < scalars.count {
            guard scalars[index] == "_", isProse(index) else {
                index += 1
                continue
            }
            var end = index + 1
            while end < scalars.count, scalars[end] == "_", isProse(end) {
                end += 1
            }
            defer { index = end }

            var start = index
            if character(at: start - 1) == "\\" {
                start += 1
            }
            guard end - start >= 2 else { continue }
            if isWordCharacter(at: start - 1), isWordCharacter(at: end) {
                continue
            }
            if isWhitespaceOrEdge(at: start - 1), isWhitespaceOrEdge(at: end),
               StreamingMarkdownRepair.isHorizontalRule(scalars, markerIndex: start, marker: "_") {
                continue
            }
            if inMath(start) || inLinkURL(start) {
                continue
            }
            if ((end - start) / 2) % 2 == 1 {
                unmatched.toggle()
            }
        }
        return unmatched
    }

    private static func buildMathMask(_ scalars: [Unicode.Scalar], spans: SpanScan) -> [Bool] {
        guard scalars.contains("$") else { return [] }
        var mask = Array(repeating: false, count: scalars.count)
        var inline = false
        var display = false
        var index = 0
        while index < scalars.count {
            mask[index] = inline || display
            if scalars[index] == "\\" {
                index += 2
                continue
            }
            guard scalars[index] == "$", spans.isProse(index) else {
                index += 1
                continue
            }
            if index + 1 < scalars.count, scalars[index + 1] == "$" {
                display.toggle()
                mask[index + 1] = inline || display
                index += 2
            } else {
                if !display {
                    inline.toggle()
                }
                index += 1
            }
        }
        return mask
    }

    private static func buildLinkURLMask(_ scalars: [Unicode.Scalar], spans: SpanScan) -> [Bool] {
        guard scalars.count >= 2 else { return [] }
        var mask = Array(repeating: false, count: scalars.count)
        var lineStart = 0
        while lineStart < scalars.count {
            let lineEnd = scalars[lineStart...].firstIndex(of: "\n") ?? scalars.count
            var closerFollows = Array(repeating: false, count: lineEnd - lineStart)
            var seenCloser = false
            for index in stride(from: lineEnd - 1, through: lineStart, by: -1) {
                if scalars[index] == ")", spans.isProse(index) {
                    seenCloser = true
                }
                closerFollows[index - lineStart] = seenCloser
            }
            var inURL = false
            for index in lineStart..<lineEnd {
                if inURL, closerFollows[index - lineStart] {
                    mask[index] = true
                }
                guard spans.isProse(index) else { continue }
                if scalars[index] == ")" {
                    inURL = false
                } else if scalars[index] == "(" {
                    inURL = index > 0 && scalars[index - 1] == "]"
                }
            }
            lineStart = lineEnd + 1
        }
        return mask
    }
}
