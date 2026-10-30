public struct MarkdownParsingOptions: Sendable, Equatable {
    public var underline: Bool
    public var superscript: Bool
    public var `subscript`: Bool
    public var highlight: Bool
    public var hardSoftBreaks: Bool
    public var permissiveAutolinks: Bool
    public var preserveBlankLines: Bool
    /// Keeps backslashes that separate a Windows drive path (`C:\\Users\\me\\.config`)
    /// instead of treating them as escapes. Off by default; CommonMark drops them.
    public var preserveWindowsPaths: Bool
    public var admonitions: Bool

    /// Set only via `MarkdownRenderPlugin.adjustParsingOptions` (the
    /// EnrichedMarkdownLaTeX product) — base cannot render math nodes.
    package var latexMathEnabled: Bool = false

    public init(
        underline: Bool = false,
        superscript: Bool = false,
        subscript subscriptEnabled: Bool = false,
        highlight: Bool = false,
        hardSoftBreaks: Bool = false,
        permissiveAutolinks: Bool = true,
        preserveBlankLines: Bool = false,
        preserveWindowsPaths: Bool = false,
        admonitions: Bool = false
    ) {
        self.underline = underline
        self.superscript = superscript
        self.subscript = subscriptEnabled
        self.highlight = highlight
        self.hardSoftBreaks = hardSoftBreaks
        self.permissiveAutolinks = permissiveAutolinks
        self.preserveBlankLines = preserveBlankLines
        self.preserveWindowsPaths = preserveWindowsPaths
        self.admonitions = admonitions
    }

    public static let commonMark = MarkdownParsingOptions()
}
