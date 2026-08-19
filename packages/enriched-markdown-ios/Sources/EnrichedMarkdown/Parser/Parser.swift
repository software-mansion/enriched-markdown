public final class Parser: Sendable {
    public static let shared = Parser()

    public init() {}

    public func parseMarkdown(
        _ markdown: String,
        flags: Md4cFlags = .commonMark
    ) -> MarkdownASTNode {
        MarkdownParserBridge.parse(markdown, flags: flags)
    }
}
