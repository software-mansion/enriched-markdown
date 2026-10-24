public final class Parser: Sendable {
    public static let shared = Parser()

    public init() {}

    public func parseMarkdown(
        _ markdown: String,
        options: MarkdownParsingOptions = .commonMark
    ) -> MarkdownASTNode {
        MarkdownParserBridge.parse(markdown, options: options)
    }
}
