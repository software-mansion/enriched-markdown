public struct Md4cFlags: Sendable, Equatable {
    public var underline: Bool
    public var latexMath: Bool
    public var superscript: Bool
    public var `subscript`: Bool
    public var highlight: Bool
    public var permissiveAutolinks: Bool

    public init(
        underline: Bool = false,
        latexMath: Bool = false,
        superscript: Bool = false,
        subscript subscriptEnabled: Bool = false,
        highlight: Bool = false,
        permissiveAutolinks: Bool = true
    ) {
        self.underline = underline
        self.latexMath = latexMath
        self.superscript = superscript
        self.subscript = subscriptEnabled
        self.highlight = highlight
        self.permissiveAutolinks = permissiveAutolinks
    }

    public static let commonMark = Md4cFlags()
}
