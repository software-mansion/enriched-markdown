public struct Md4cFlags: Sendable, Equatable {
    public var underline: Bool
    public var latexMath: Bool
    public var superscript: Bool
    public var `subscript`: Bool
    public var highlight: Bool
    public var hardSoftBreaks: Bool
    public var permissiveAutolinks: Bool
    public var preserveBlankLines: Bool
    public var admonitions: Bool

    public init(
        underline: Bool = false,
        latexMath: Bool = false,
        superscript: Bool = false,
        subscript subscriptEnabled: Bool = false,
        highlight: Bool = false,
        hardSoftBreaks: Bool = false,
        permissiveAutolinks: Bool = true,
        preserveBlankLines: Bool = false,
        admonitions: Bool = false
    ) {
        self.underline = underline
        self.latexMath = latexMath
        self.superscript = superscript
        self.subscript = subscriptEnabled
        self.highlight = highlight
        self.hardSoftBreaks = hardSoftBreaks
        self.permissiveAutolinks = permissiveAutolinks
        self.preserveBlankLines = preserveBlankLines
        self.admonitions = admonitions
    }

    public static let commonMark = Md4cFlags()
}
