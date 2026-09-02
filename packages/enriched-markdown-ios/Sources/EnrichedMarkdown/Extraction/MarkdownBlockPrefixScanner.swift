import Foundation

/// Walks a candidate block-prefix byte slice (the bytes between a line
/// start and a selection's first mapped byte) so the slicer can decide
/// whether everything in between is marker syntax: indentation, blockquote
/// bars, a list marker with optional task box, and heading hashes.
struct MarkdownBlockPrefixScanner {
    let slice: ArraySlice<UInt8>
    var index: Int

    init(slice: ArraySlice<UInt8>) {
        self.slice = slice
        self.index = slice.startIndex
    }

    var isAtEnd: Bool { index == slice.endIndex }

    func peek() -> UInt8? { index < slice.endIndex ? slice[index] : nil }

    mutating func consumeWhitespace() -> Bool {
        let start = index
        while let byte = peek(), byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\t") {
            index += 1
        }
        return index > start
    }

    mutating func consumeIndentAndBars() {
        while let byte = peek(),
              byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\t") || byte == UInt8(ascii: ">") {
            index += 1
        }
    }

    /// "-", "*", "+", "1.", or "1)" followed by whitespace.
    mutating func consumeListMarker() -> Bool {
        let start = index
        if let byte = peek(), [UInt8(ascii: "-"), UInt8(ascii: "*"), UInt8(ascii: "+")].contains(byte) {
            index += 1
            if consumeWhitespace() { return true }
        } else if let byte = peek(), (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) {
            while let digit = peek(), (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(digit) {
                index += 1
            }
            if let punct = peek(), punct == UInt8(ascii: ".") || punct == UInt8(ascii: ")") {
                index += 1
                if consumeWhitespace() { return true }
            }
        }
        index = start
        return false
    }

    /// "[ ]", "[x]", or "[X]" followed by whitespace.
    mutating func consumeTaskBox() {
        let start = index
        guard peek() == UInt8(ascii: "[") else { return }
        index += 1
        let state = peek()
        guard state == UInt8(ascii: " ") || state == UInt8(ascii: "x") || state == UInt8(ascii: "X") else {
            index = start
            return
        }
        index += 1
        guard peek() == UInt8(ascii: "]") else {
            index = start
            return
        }
        index += 1
        if !consumeWhitespace() {
            index = start
        }
    }

    /// Up to six "#" followed by whitespace.
    mutating func consumeHeadingHashes() {
        let start = index
        var count = 0
        while peek() == UInt8(ascii: "#") {
            index += 1
            count += 1
        }
        if count == 0 { return }
        if count > 6 || !consumeWhitespace() {
            index = start
        }
    }
}
