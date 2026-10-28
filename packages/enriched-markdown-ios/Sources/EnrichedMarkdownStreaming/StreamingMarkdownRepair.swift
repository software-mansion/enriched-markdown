import EnrichedMarkdown
import EnrichedMarkdownRepair

enum StreamingMarkdownRepair {
    static func repair(_ markdown: String, options: MarkdownParsingOptions) -> String {
        guard let repaired = em_repair_inline_markdown(markdown, options.highlight ? 1 : 0, options.latexMathEnabled ? 1 : 0)
        else { return markdown }
        defer { em_repair_release(repaired) }
        return String(cString: repaired)
    }
}
