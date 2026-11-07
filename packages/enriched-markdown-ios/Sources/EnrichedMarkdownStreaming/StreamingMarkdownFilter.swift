import EnrichedMarkdownCppShim

enum StreamingMarkdownFilter {
    struct Result {
        let markdown: String
        let endsInsideOpenCodeFence: Bool
    }

    static func renderable(_ markdown: String, options: MarkdownStreamingOptions) -> Result {
        var endsInsideOpenCodeFence: Int32 = 0
        guard let filtered = em_renderable_markdown_for_streaming(
            markdown,
            options.tables == .hidden ? 1 : 0,
            options.codeBlocks == .hidden ? 1 : 0,
            &endsInsideOpenCodeFence
        ) else { return Result(markdown: markdown, endsInsideOpenCodeFence: false) }
        defer { em_string_release(filtered) }
        return Result(markdown: String(cString: filtered), endsInsideOpenCodeFence: endsInsideOpenCodeFence != 0)
    }
}
