import UIKit

enum BlockType {
    case none
    case paragraph
}

struct BlockStyle {
    var font: UIFont
    var color: UIColor
}

enum MarkdownAttribute {
    static let inlineCode = NSAttributedString.Key("EnrichedMarkdownInlineCode")
}

final class RenderContext {
  private(set) var currentBlockType: BlockType = .none
  private(set) var currentBlockStyle: BlockStyle?

    func reset() {
        currentBlockType = .none
        currentBlockStyle = nil
    }

    func setBlockStyle(font: UIFont, color: UIColor) {
        currentBlockType = .paragraph
        currentBlockStyle = BlockStyle(font: font, color: color)
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
