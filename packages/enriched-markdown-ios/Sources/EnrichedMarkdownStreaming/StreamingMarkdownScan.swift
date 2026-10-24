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
