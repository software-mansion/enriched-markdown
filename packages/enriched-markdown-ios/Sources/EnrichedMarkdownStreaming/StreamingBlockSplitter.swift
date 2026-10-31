import EnrichedMarkdown
import Foundation

enum StreamingBlockSplitter {
    struct Scan: Equatable {
        var lastCut: Int?
        var hasLinkReferenceDefinition = false
    }

    static func scan(_ bytes: [UInt8]) -> Scan {
        var result = Scan()
        var fence: FenceMarker?
        var previousLineBlank = false
        var lineStart = 0

        while lineStart < bytes.count {
            let lineEnd = bytes[lineStart...].firstIndex(of: UInt8(ascii: "\n")) ?? bytes.count
            let line = bytes[lineStart..<lineEnd]

            if let open = fence {
                if let marker = fenceMarker(in: line), marker.closes(open) {
                    fence = nil
                }
                previousLineBlank = false
                lineStart = lineEnd + 1
                continue
            }

            if isLinkReferenceDefinition(line) {
                result.hasLinkReferenceDefinition = true
            }
            if startsRawHTML(line) {
                return result
            }
            if lineStart > 0, previousLineBlank, canStartIndependentBlock(line) {
                result.lastCut = lineStart
            }
            fence = fenceMarker(in: line)
            previousLineBlank = isBlank(line)
            lineStart = lineEnd + 1
        }
        return result
    }

    private static func isBlank(_ line: ArraySlice<UInt8>) -> Bool {
        line.allSatisfy { $0 == UInt8(ascii: " ") || $0 == UInt8(ascii: "\t") || $0 == UInt8(ascii: "\r") }
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

    private struct FenceMarker {
        let character: UInt8
        let length: Int
        let infoIsBlank: Bool

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
        return FenceMarker(character: character, length: end - scanner.index, infoIsBlank: isBlank(info))
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
