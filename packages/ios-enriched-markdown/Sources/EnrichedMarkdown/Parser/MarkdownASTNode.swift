public enum NodeType: Int, CaseIterable, Sendable {
    case document
    case paragraph
    case text
    case link
    case heading
    case lineBreak
    case strong
    case emphasis
    case strikethrough
    case underline
    case code
    case image
    case blockquote
    case unorderedList
    case orderedList
    case listItem
    case codeBlock
    case thematicBreak
    case table
    case tableHead
    case tableBody
    case tableRow
    case tableHeaderCell
    case tableCell
    case latexMathInline
    case latexMathDisplay
    case spoiler
    case superscript
    case `subscript`
    case highlight
}

public struct MarkdownASTNode: Sendable, Equatable {
    public let type: NodeType
    public let content: String
    public let attributes: [String: String]
    public let children: [MarkdownASTNode]

    public init(
        type: NodeType,
        content: String = "",
        attributes: [String: String] = [:],
        children: [MarkdownASTNode] = []
    ) {
        self.type = type
        self.content = content
        self.attributes = attributes
        self.children = children
    }

    public func attribute(_ key: String) -> String? {
        attributes[key]
    }
}
