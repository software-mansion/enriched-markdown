import Foundation

enum StreamingMarkdownFilter {
    static func renderable(
        _ markdown: String,
        openFenceStart: Int?,
        options: MarkdownStreamingOptions,
        latexMath: Bool
    ) -> String {
        guard let openFenceStart else {
            return removePendingTablesAndMath(Lines(markdown), tables: options.tables, latexMath: latexMath)
        }
        let fence = markdown.utf8.index(markdown.utf8.startIndex, offsetBy: openFenceStart)
        let head = removePendingTablesAndMath(Lines(String(markdown[..<fence])), tables: options.tables, latexMath: latexMath)
        switch options.codeBlocks {
        case .hidden:
            return head
        case .progressive:
            return head + markdown[fence...]
        }
    }

    struct Lines {
        let text: String
        let lines: [Substring]

        init(_ text: String) {
            self.text = text
            self.lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        }

        var count: Int { lines.count }

        subscript(index: Int) -> Substring { lines[index] }

        func prefix(before index: Int) -> String {
            String(text[..<lines[index].startIndex])
        }
    }

    private static func removePendingTablesAndMath(
        _ lines: Lines,
        tables: MarkdownStreamingOptions.TableMode,
        latexMath: Bool
    ) -> String {
        var lines = lines
        if latexMath, let mathLine = unclosedMathBlockLineIndex(in: lines) {
            lines = Lines(lines.prefix(before: mathLine))
        }
        return removePendingTable(lines, mode: tables)
    }

    private static func unclosedMathBlockLineIndex(in lines: Lines) -> Int? {
        var open: Int?
        for index in 0..<lines.count where trimmed(lines[index]) == "$$" {
            open = open == nil ? index : nil
        }
        return open
    }

    private static func removePendingTable(_ lines: Lines, mode: MarkdownStreamingOptions.TableMode) -> String {
        guard let lastContent = (0..<lines.count).last(where: { !isBlank(lines[$0]) }) else {
            return lines.text
        }
        if lastContent + 1 < lines.count - 1 {
            return lines.text
        }

        var blockStart = lastContent
        while blockStart > 0, !isBlank(lines[blockStart - 1]) {
            blockStart -= 1
        }
        guard (blockStart...lastContent).allSatisfy({ looksLikeTableRow(lines[$0]) }) else {
            return lines.text
        }

        switch mode {
        case .hidden:
            return lines.prefix(before: blockStart)
        case .progressive:
            let rowCount = lastContent - blockStart + 1
            if rowCount < 2 || !looksLikeTableSeparator(lines[blockStart + 1]) {
                return lines.prefix(before: blockStart)
            }
            if rowCount > 2 {
                let lastRow = lines[lastContent]
                if !trimmed(lastRow).hasSuffix("|") || pipeCount(lastRow) < pipeCount(lines[blockStart]) {
                    return lines.prefix(before: lastContent)
                }
            }
            return lines.text
        }
    }

    private static func looksLikeTableRow(_ line: Substring) -> Bool {
        trimmed(line).hasPrefix("|")
    }

    private static func looksLikeTableSeparator(_ line: Substring) -> Bool {
        let row = trimmed(line)
        guard row.first == "|" else { return false }
        var dashRun = 0
        var hasTripleDash = false
        for character in row {
            if character == "-" {
                dashRun += 1
                hasTripleDash = hasTripleDash || dashRun >= 3
            } else {
                dashRun = 0
                if character != "|", character != ":", character != " " {
                    return false
                }
            }
        }
        return hasTripleDash
    }

    private static func pipeCount(_ line: Substring) -> Int {
        line.reduce(0) { $1 == "|" ? $0 + 1 : $0 }
    }

    private static func trimmed(_ line: Substring) -> Substring {
        var trimmed = line
        while let first = trimmed.first, first == " " || first == "\t" {
            trimmed.removeFirst()
        }
        while let last = trimmed.last, last == " " || last == "\t" {
            trimmed.removeLast()
        }
        return trimmed
    }

    static func isBlank(_ line: Substring) -> Bool {
        line.allSatisfy { $0 == " " || $0 == "\t" || $0 == "\r" }
    }
}
