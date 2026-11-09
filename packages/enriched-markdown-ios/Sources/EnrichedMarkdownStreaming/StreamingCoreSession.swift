import EnrichedMarkdown
import EnrichedMarkdownStreamingCore

final class StreamingCoreSession {
    struct Update {
        let lineage: UInt64
        let frozenBytes: Int
        let finishedBytes: Int
        let finishedContinuesList: Bool
        let finishedContinuedByTail: Bool
        let tail: String
        let tailContinuesList: Bool
        let tailEndsInsideOpenCodeFence: Bool
        let tailCodeBodyStart: Int?
    }

    private let session: OpaquePointer?

    init(options: MarkdownParsingOptions) {
        session = em_streaming_session_create(
            options.highlight ? 1 : 0,
            options.latexMathEnabled ? 1 : 0,
            options.superscript ? 1 : 0,
            options.subscript ? 1 : 0,
            options.preserveBlankLines ? 0 : 1
        )
    }

    deinit {
        em_streaming_session_release(session)
    }

    func update(_ markdown: String, options: MarkdownStreamingOptions, restartingOpenList: Bool = false) -> Update {
        var raw = EMStreamingUpdate()
        em_streaming_session_update(
            session,
            markdown,
            options.tables == .hidden ? 1 : 0,
            options.codeBlocks == .hidden ? 1 : 0,
            options.media == .hidden ? 1 : 0,
            restartingOpenList ? 1 : 0,
            &raw
        )
        defer { em_streaming_update_release(&raw) }
        let tail = raw.tail.map { String(cString: $0) } ?? markdown
        let bodyStart = Int(bitPattern: UInt(bitPattern: raw.tailCodeBodyStart))
        return Update(
            lineage: raw.lineage,
            frozenBytes: Int(raw.frozenBytes),
            finishedBytes: Int(raw.finishedBytes),
            finishedContinuesList: raw.finishedContinuesList != 0,
            finishedContinuedByTail: raw.finishedContinuedByTail != 0,
            tail: tail,
            tailContinuesList: raw.tailContinuesList != 0,
            tailEndsInsideOpenCodeFence: raw.tailEndsInsideOpenCodeFence != 0,
            tailCodeBodyStart: bodyStart >= 0 && bodyStart <= tail.utf8.count ? bodyStart : nil
        )
    }
}
