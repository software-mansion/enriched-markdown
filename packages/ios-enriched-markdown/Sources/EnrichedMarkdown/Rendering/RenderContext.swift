import UIKit

enum BlockType {
    case none
    case paragraph
    case heading
    case codeBlock
    case blockquote
    case orderedList
    case unorderedList
}

enum ListType: Int {
    case unordered = 0
    case ordered = 1
}

struct BlockStyle {
    var font: UIFont
    var color: UIColor
    var headingLevel: Int
}

enum MarkdownAttribute {
    static let inlineCode = NSAttributedString.Key("EnrichedMarkdownInlineCode")
    static let codeBlock = NSAttributedString.Key("EnrichedMarkdownCodeBlock")
    static let blockquoteDepth = NSAttributedString.Key("EnrichedMarkdownBlockquoteDepth")
    static let blockquoteBackgroundColor = NSAttributedString.Key("EnrichedMarkdownBlockquoteBackgroundColor")
    static let listDepth = NSAttributedString.Key("EnrichedMarkdownListDepth")
    static let listType = NSAttributedString.Key("EnrichedMarkdownListType")
    static let listItemNumber = NSAttributedString.Key("EnrichedMarkdownListItemNumber")
}

final class RenderContext {
    private(set) var currentBlockType: BlockType = .none
    private(set) var currentBlockStyle: BlockStyle?

    var blockquoteDepth = 0
    var listDepth = 0
    var listType: ListType = .unordered
    var listItemNumber = 0
    var rendersBlockImage = false

    private static let blockSpacerTemplate: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = 1
        style.maximumLineHeight = 1
        return style
    }()

    func reset() {
        currentBlockType = .none
        currentBlockStyle = nil
        blockquoteDepth = 0
        listDepth = 0
        listType = .unordered
        listItemNumber = 0
        rendersBlockImage = false
    }

    func setBlockStyle(
        font: UIFont,
        color: UIColor,
        blockType: BlockType = .paragraph,
        headingLevel: Int = 0
    ) {
        currentBlockType = blockType
        currentBlockStyle = BlockStyle(font: font, color: color, headingLevel: headingLevel)
    }

    func clearBlockStyle() {
        currentBlockType = .none
        currentBlockStyle = nil
    }

    func getBlockStyle() -> BlockStyle? {
        currentBlockStyle
    }

    func getTextAttributes() -> [NSAttributedString.Key: Any] {
        guard let blockStyle = currentBlockStyle else {
            return [:]
        }
        return [
            .font: blockStyle.font,
            .foregroundColor: blockStyle.color
        ]
    }

    func spacerStyle(height: CGFloat, spacing: CGFloat = 0) -> NSMutableParagraphStyle {
        guard let style = Self.blockSpacerTemplate.mutableCopy() as? NSMutableParagraphStyle else {
            return NSMutableParagraphStyle()
        }
        style.minimumLineHeight = height
        style.maximumLineHeight = height
        style.paragraphSpacing = spacing
        return style
    }

    static func shouldPreserveColors(_ attributes: [NSAttributedString.Key: Any]) -> Bool {
        attributes[.link] != nil || attributes[MarkdownAttribute.inlineCode] != nil
    }

    static func rangeForRenderedContent(in output: NSMutableAttributedString, start: Int) -> NSRange {
        let length = output.length - start
        guard length > 0 else { return NSRange(location: start, length: 0) }
        return NSRange(location: start, length: length)
    }

    static func calculateStrongColor(configColor: UIColor?, blockColor: UIColor) -> UIColor? {
        guard let configColor, !configColor.isEqual(blockColor) else {
            return nil
        }
        return configColor
    }
}
