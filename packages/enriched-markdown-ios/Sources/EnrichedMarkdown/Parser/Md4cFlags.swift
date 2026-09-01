public struct Md4cFlags: Sendable, Equatable {
    public var underline: Bool
    public var superscript: Bool
    public var `subscript`: Bool
    public var highlight: Bool
    public var hardSoftBreaks: Bool
    public var permissiveAutolinks: Bool
    public var preserveBlankLines: Bool

    /// Set only via `MarkdownRenderPlugin.adjustFlags` (the
    /// EnrichedMarkdownLaTeX product) — base cannot render math nodes.
    package var latexMathEnabled: Bool = false

    public init(
        underline: Bool = false,
        superscript: Bool = false,
        subscript subscriptEnabled: Bool = false,
        highlight: Bool = false,
        hardSoftBreaks: Bool = false,
        permissiveAutolinks: Bool = true,
        preserveBlankLines: Bool = false
    ) {
        self.underline = underline
        self.superscript = superscript
        self.subscript = subscriptEnabled
        self.highlight = highlight
        self.hardSoftBreaks = hardSoftBreaks
        self.permissiveAutolinks = permissiveAutolinks
        self.preserveBlankLines = preserveBlankLines
    }

    public static let commonMark = Md4cFlags()
}
