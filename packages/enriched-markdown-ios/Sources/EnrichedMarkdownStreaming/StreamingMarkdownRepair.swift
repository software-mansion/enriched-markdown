import EnrichedMarkdown
import Foundation

enum StreamingMarkdownRepair {
    struct Syntax: Equatable {
        var latexMath = false
        var highlight = false
    }

    static func repair(_ markdown: String, syntax: Syntax = Syntax()) -> String {
        var text = Array(markdown.unicodeScalars)
        if let fence = FenceScan.openFence(in: text) {
            return String(String.UnicodeScalarView(removingPartialCloser(of: fence, from: text)))
        }

        text = removingTrailingMarkerLine(text)
        let scopeStart = inlineScopeStart(in: text)
        var scopeEnd = text.count
        while scopeEnd > scopeStart, isWhitespace(text[scopeEnd - 1]) {
            scopeEnd -= 1
        }

        var scope = Array(text[scopeStart..<scopeEnd])
        if syntax.latexMath {
            scope = truncatingUnclosedMath(scope)
        }
        scope = healingTrailingLinks(scope)
        scope = droppingTrailingOpeners(scope)
        while let last = scope.last, isWhitespace(last) {
            scope.removeLast()
        }

        var result = String.UnicodeScalarView()
        result.append(contentsOf: text[..<scopeStart])
        result.append(contentsOf: scope)
        result.append(contentsOf: closers(for: scope, syntax: syntax))
        result.append(contentsOf: text[scopeEnd...])
        return String(result)
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
        } else {
            isMarkerOnly = listMarkerLength(remainder, at: 0) == remainder.count
        }
        return isMarkerOnly ? Array(text[..<lineStart]) : text
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
    // MARK: - Closers

    private struct Closer {
        let opener: Int
        let text: String
        let completesTrailingRun: Bool
    }

    private static func closers(for text: [Unicode.Scalar], syntax: Syntax) -> String.UnicodeScalarView {
        var rules: [(InlineText) -> Closer?] = [
            boldItalicCloser, boldCloser, doubleUnderscoreCloser, singleAsteriskCloser,
            singleUnderscoreCloser, inlineCodeCloser,
            { doubleMarkerCloser($0, marker: "~") },
            { doubleMarkerCloser($0, marker: "|") }
        ]
        if syntax.highlight {
            rules.append { doubleMarkerCloser($0, marker: "=") }
        }

        var virtual = text
        var inline = InlineText(virtual, latexMath: syntax.latexMath)
        var closers: [Closer] = []
        for rule in rules {
            guard let closer = rule(inline) else { continue }
            closers.append(closer)
            virtual.append(contentsOf: closer.text.unicodeScalars)
            inline = InlineText(virtual, latexMath: syntax.latexMath)
        }

        let ordered = closers.filter(\.completesTrailingRun)
            + closers.filter { !$0.completesTrailingRun }.sorted { $0.opener > $1.opener }
        var result = String.UnicodeScalarView()
        for closer in ordered {
            result.append(contentsOf: closer.text.unicodeScalars)
        }
        return result
    }

    private static func boldItalicCloser(_ text: InlineText) -> Closer? {
        let scalars = text.scalars
        if scalars.count >= 4, scalars.allSatisfy({ $0 == "*" }) {
            return nil
        }
        guard let match = text.trailingRun(of: "*", length: 3),
              text.isProse(match.marker),
              !isMarkersOnly(scalars[match.content]),
              !isWhitespace(scalars[match.marker + 3]),
              !isHorizontalRule(scalars, markerIndex: match.marker, marker: "*"),
              text.countTripleAsterisks() % 2 == 1
        else { return nil }
        if text.countDoublePairs(of: "*") % 2 == 0, text.countSingleAsterisks() % 2 == 0 {
            return nil
        }
        return Closer(opener: match.marker, text: "***", completesTrailingRun: false)
    }

    private static func boldCloser(_ text: InlineText) -> Closer? {
        let scalars = text.scalars
        if let match = text.halfCompleteRun(of: "*") {
            guard text.isProse(match.marker),
                  !shouldSkipCompletion(text, match: match, marker: "*"),
                  text.countDoublePairs(of: "*") % 2 == 1
            else { return nil }
            return Closer(opener: match.marker, text: "*", completesTrailingRun: true)
        }
        let pairs = text.doublePairs(of: "*")
        guard pairs.count % 2 == 1, let marker = pairs.last else { return nil }
        let match = InlineText.Match(marker: marker, content: (marker + 2)..<scalars.count)
        guard !shouldSkipCompletion(text, match: match, marker: "*") else { return nil }
        return Closer(opener: marker, text: "**", completesTrailingRun: false)
    }

    private static func doubleUnderscoreCloser(_ text: InlineText) -> Closer? {
        if let match = text.trailingRun(of: "_", length: 2) {
            guard text.isProse(match.marker),
                  !shouldSkipCompletion(text, match: match, marker: "_"),
                  text.hasUnmatchedDoubleUnderscore()
            else { return nil }
            return Closer(opener: match.marker, text: "__", completesTrailingRun: false)
        }
        guard let match = text.halfCompleteRun(of: "_"),
              text.isProse(match.marker),
              text.hasUnmatchedDoubleUnderscore()
        else { return nil }
        return Closer(opener: match.marker, text: "_", completesTrailingRun: true)
    }

    private static func singleAsteriskCloser(_ text: InlineText) -> Closer? {
        let scalars = text.scalars
        guard scalars.contains("*"),
              let first = text.firstSingleAsteriskIndex(),
              text.isProse(first),
              !isMarkersOnly(scalars[(first + 1)...]),
              text.countSingleAsterisks() % 2 == 1
        else { return nil }
        return Closer(opener: first, text: "*", completesTrailingRun: false)
    }

    private static func singleUnderscoreCloser(_ text: InlineText) -> Closer? {
        let scalars = text.scalars
        guard scalars.contains("_"),
              let first = text.firstSingleUnderscoreIndex(),
              !isMarkersOnly(scalars[(first + 1)...]),
              text.isProse(first),
              text.countSingleUnderscores() % 2 == 1
        else { return nil }
        return Closer(opener: first, text: "_", completesTrailingRun: false)
    }

    private static func inlineCodeCloser(_ text: InlineText) -> Closer? {
        guard let span = text.spans.openSpan else { return nil }
        let scalars = text.scalars
        guard !isMarkersOnly(scalars[(span.start + span.runLength)...]) else { return nil }
        var trailingRun = 0
        while trailingRun < scalars.count, scalars[scalars.count - 1 - trailingRun] == "`" {
            trailingRun += 1
        }
        guard trailingRun < span.runLength else { return nil }
        return Closer(
            opener: span.start,
            text: String(repeating: "`", count: span.runLength - trailingRun),
            completesTrailingRun: trailingRun > 0
        )
    }

    private static func doubleMarkerCloser(_ text: InlineText, marker: Unicode.Scalar) -> Closer? {
        let scalars = text.scalars
        if let match = text.trailingRun(of: marker, length: 2) {
            guard !isMarkersOnly(scalars[match.content]),
                  !isWhitespace(scalars[match.marker + 2]),
                  text.isProse(match.marker),
                  text.countDoublePairs(of: marker) % 2 == 1
            else { return nil }
            let closer = String(repeating: Character(marker), count: 2)
            return Closer(opener: match.marker, text: closer, completesTrailingRun: false)
        }
        guard let match = text.halfCompleteRun(of: marker),
              text.isProse(match.marker),
              text.countDoublePairs(of: marker) % 2 == 1
        else { return nil }
        return Closer(opener: match.marker, text: String(Character(marker)), completesTrailingRun: true)
    }

    private static func shouldSkipCompletion(_ text: InlineText, match: InlineText.Match, marker: Unicode.Scalar) -> Bool {
        let scalars = text.scalars
        let content = scalars[match.content]
        if isMarkersOnly(content) {
            return true
        }
        if isWhitespace(scalars[match.content.lowerBound]) {
            return true
        }
        let lineStart = (scalars[..<match.marker].lastIndex(of: "\n") ?? -1) + 1
        let beforeMarker = scalars[lineStart..<match.marker]
        if isBareListMarker(beforeMarker), content.contains("\n") {
            return true
        }
        return isHorizontalRule(scalars, markerIndex: match.marker, marker: marker)
    }

    // MARK: - Character classes

    static func isWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        scalar == " " || scalar == "\t" || scalar == "\n" || scalar == "\r"
    }

    static func isWordCharacter(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "_" || scalar.properties.isAlphabetic || scalar.properties.numericType != nil
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

    private static func isMarkersOnly(_ content: ArraySlice<Unicode.Scalar>) -> Bool {
        content.allSatisfy { isWhitespace($0) || "_~*`".unicodeScalars.contains($0) }
    }

    private static func isBareListMarker(_ line: ArraySlice<Unicode.Scalar>) -> Bool {
        let scalars = Array(line.drop(while: isWhitespace))
        guard let length = listMarkerLength(scalars, at: 0) else { return false }
        return scalars.count > length && scalars[length...].allSatisfy(isWhitespace)
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

    static func lastIndex(of first: Unicode.Scalar, then second: Unicode.Scalar, in text: [Unicode.Scalar]) -> Int? {
        guard text.count >= 2 else { return nil }
        var index = text.count - 2
        while index >= 0 {
            if text[index] == first, text[index + 1] == second {
                return index
            }
            index -= 1
        }
        return nil
    }
}

extension StreamingMarkdownRepair.Syntax {
    init(options: MarkdownParsingOptions) {
        self.init(latexMath: options.latexMathEnabled, highlight: options.highlight)
    }
}
