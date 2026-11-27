import EnrichedMarkdown
import EnrichedMarkdownCppShim

struct StreamingSnapshot {
    let finishedBytes: Int
    let finishedItemsBytes: Int
    let lastItemBytes: Int
    let tail: String
    let endsInsideOpenCodeFence: Bool
    let mayDefineLinkReference: Bool

    init(of markdown: String, from offset: Int, parsing: MarkdownParsingOptions, streaming: MarkdownStreamingOptions) {
        var raw = EMCStreamingSnapshot()
        defer { em_streaming_snapshot_release(&raw) }
        let unprepared = markdown.withCString { start -> String? in
            em_streaming_snapshot(
                start + offset,
                parsing.latexMathEnabled ? 1 : 0,
                parsing.superscript ? 1 : 0,
                parsing.subscript ? 1 : 0,
                parsing.highlight ? 1 : 0,
                streaming.tables == .hidden ? 1 : 0,
                streaming.codeBlocks == .hidden ? 1 : 0,
                streaming.media == .hidden ? 1 : 0,
                &raw
            )
            return raw.tail == nil ? String(cString: start + offset) : nil
        }
        finishedBytes = raw.tail == nil ? 0 : Int(raw.finishedBytes)
        finishedItemsBytes = raw.tail == nil ? 0 : Int(raw.finishedItemsBytes)
        lastItemBytes = raw.tail == nil ? 0 : Int(raw.lastItemBytes)
        tail = raw.tail.map { String(cString: $0) } ?? unprepared ?? ""
        endsInsideOpenCodeFence = raw.endsInsideOpenCodeFence != 0
        mayDefineLinkReference = raw.mayDefineLinkReference != 0
    }
}
