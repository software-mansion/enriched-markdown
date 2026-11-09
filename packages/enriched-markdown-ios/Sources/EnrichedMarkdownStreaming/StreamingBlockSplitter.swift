import EnrichedMarkdown
import Foundation

enum StreamingBlockSplitter {
    struct Cut: Equatable {
        let offset: Int
        let continuesList: Bool
    }

    struct OpenFence: Equatable {
        let start: Int
        let character: UInt8
        let length: Int
    }

    struct Scan: Equatable {
        var lastCut: Cut?
        var lastBlockCut: Cut?
        var openFence: OpenFence?
        var hasLinkReferenceDefinition = false

        fileprivate mutating func cut(at offset: Int, continuingList: Bool) {
            lastCut = Cut(offset: offset, continuesList: continuingList)
            if !continuingList {
                lastBlockCut = lastCut
            }
        }
    }

    private struct Lines {
        var openList: UInt8?
        var previousLineBlank = false
        var insideHTMLBlock = false
    }

    static func scan(_ bytes: [UInt8]) -> Scan {
        var result = Scan()
        var fence: (marker: FenceMarker, start: Int)?
        var lines = Lines()
        var lineStart = 0

        while lineStart < bytes.count {
            let lineEnd = bytes[lineStart...].firstIndex(of: UInt8(ascii: "\n")) ?? bytes.count
            let line = bytes[lineStart..<lineEnd]

            if let open = fence {
                if let marker = fenceMarker(in: line), marker.closes(open.marker) {
                    fence = nil
                }
                lines.previousLineBlank = false
                lineStart = lineEnd + 1
                continue
            }

            if isLinkReferenceDefinition(line) {
                result.hasLinkReferenceDefinition = true
            }
            if startsRawHTML(line) {
                return result
            }
            visit(line, at: lineStart, lines: &lines, result: &result)
            if let marker = fenceMarker(in: line) {
                fence = (marker, lineStart)
            }
            lineStart = lineEnd + 1
        }
        if let fence, fence.marker.isTopLevel {
            result.openFence = OpenFence(start: fence.start, character: fence.marker.character, length: fence.marker.length)
        }
        return result
    }

    private static func visit(_ line: ArraySlice<UInt8>, at lineStart: Int, lines: inout Lines, result: inout Scan) {
        let blank = isBlank(line)
        defer { lines.previousLineBlank = blank }
        if blank {
            lines.insideHTMLBlock = false
            return
        }
        if lines.insideHTMLBlock {
            return
        }
        if line.first == UInt8(ascii: "<") {
            lines.insideHTMLBlock = true
            lines.openList = nil
            return
        }
        if let marker = topLevelListMarker(in: line) {
            visitListItem(marker, at: lineStart, lines: &lines, result: &result)
        } else if !startsIndented(line) {
            if lines.previousLineBlank {
                lines.openList = nil
            }
            if lineStart > 0, lines.previousLineBlank, canStartIndependentBlock(line) {
                result.cut(at: lineStart, continuingList: false)
            }
        }
    }

    private static func visitListItem(_ marker: UInt8, at lineStart: Int, lines: inout Lines, result: inout Scan) {
        if marker == lines.openList {
            if lineStart > 0 {
                result.cut(at: lineStart, continuingList: true)
            }
            return
        }
        lines.openList = marker
        if lineStart > 0, lines.previousLineBlank {
            result.cut(at: lineStart, continuingList: false)
        }
    }

    private static func isBlank(_ line: ArraySlice<UInt8>) -> Bool {
        line.allSatisfy { $0 == UInt8(ascii: " ") || $0 == UInt8(ascii: "\t") || $0 == UInt8(ascii: "\r") }
    }

    private static func startsIndented(_ line: ArraySlice<UInt8>) -> Bool {
        line.first == UInt8(ascii: " ") || line.first == UInt8(ascii: "\t")
    }

    private static func canStartIndependentBlock(_ line: ArraySlice<UInt8>) -> Bool {
        guard let first = line.first else { return false }
        switch first {
        case UInt8(ascii: " "), UInt8(ascii: "\t"), UInt8(ascii: "\r"),
             UInt8(ascii: "-"), UInt8(ascii: "*"), UInt8(ascii: "+"),
             UInt8(ascii: "0")...UInt8(ascii: "9"),
             UInt8(ascii: "["), UInt8(ascii: "<"):
            return false
        default:
            return true
        }
    }

    private static func topLevelListMarker(in line: ArraySlice<UInt8>) -> UInt8? {
        guard let first = line.first, !isThematicBreak(line) else { return nil }
        var scanner = MarkdownBlockPrefixScanner(slice: line)
        guard scanner.consumeListMarker() else { return nil }
        if first == UInt8(ascii: "-") || first == UInt8(ascii: "*") || first == UInt8(ascii: "+") {
            return first
        }
        let digits = line.prefix { (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0) }
        guard digits.count <= 9 else { return nil }
        return line[digits.endIndex]
    }

    private static func isThematicBreak(_ line: ArraySlice<UInt8>) -> Bool {
        let marks = line.filter { $0 != UInt8(ascii: " ") && $0 != UInt8(ascii: "\t") && $0 != UInt8(ascii: "\r") }
        guard marks.count >= 3, let first = marks.first,
              first == UInt8(ascii: "-") || first == UInt8(ascii: "*") || first == UInt8(ascii: "_")
        else { return false }
        return marks.allSatisfy { $0 == first }
    }

    private struct FenceMarker {
        let character: UInt8
        let length: Int
        let infoIsBlank: Bool
        let isTopLevel: Bool

        func closes(_ opener: FenceMarker) -> Bool {
            character == opener.character && length >= opener.length && infoIsBlank
        }
    }

    private static func fenceMarker(in line: ArraySlice<UInt8>) -> FenceMarker? {
        var scanner = MarkdownBlockPrefixScanner(slice: line)
        scanner.consumeIndentAndBars()
        while scanner.consumeListMarker() {
            scanner.consumeIndentAndBars()
        }
        guard let character = scanner.peek(), character == UInt8(ascii: "`") || character == UInt8(ascii: "~") else { return nil }
        var end = scanner.index
        while end < line.endIndex, line[end] == character {
            end += 1
        }
        guard end - scanner.index >= 3 else { return nil }
        let info = line[end...]
        if character == UInt8(ascii: "`"), info.contains(UInt8(ascii: "`")) {
            return nil
        }
        return FenceMarker(
            character: character,
            length: end - scanner.index,
            infoIsBlank: isBlank(info),
            isTopLevel: scanner.index == line.startIndex
        )
    }

    private static func isLinkReferenceDefinition(_ line: ArraySlice<UInt8>) -> Bool {
        var index = line.startIndex
        while index < line.endIndex, index - line.startIndex < 3, line[index] == UInt8(ascii: " ") {
            index += 1
        }
        guard index < line.endIndex, line[index] == UInt8(ascii: "[") else { return false }
        guard let close = line[index...].firstIndex(of: UInt8(ascii: "]")), close > index + 1 else { return false }
        return close + 1 < line.endIndex && line[close + 1] == UInt8(ascii: ":")
    }

    private static let rawHTMLOpeners = ["<!--", "<?", "<![CDATA[", "<pre", "<script", "<style", "<textarea"]
        .map { Array($0.utf8) }

    private static func startsRawHTML(_ line: ArraySlice<UInt8>) -> Bool {
        let content = line.drop { $0 == UInt8(ascii: " ") }
        guard content.first == UInt8(ascii: "<") else { return false }
        let lowered = content.prefix(9).map { (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains($0) ? $0 + 32 : $0 }
        return rawHTMLOpeners.contains { lowered.starts(with: $0) }
    }
}
