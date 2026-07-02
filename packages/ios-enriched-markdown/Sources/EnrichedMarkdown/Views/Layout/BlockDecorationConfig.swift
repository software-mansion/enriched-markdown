import UIKit

struct BlockDecorationConfig {
    var codeBlockBackgroundColor: UIColor = UIColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1)
    var codeBlockBorderColor: UIColor = UIColor(red: 0.22, green: 0.25, blue: 0.29, alpha: 1)
    var codeBlockBorderWidth: CGFloat = 1
    var codeBlockBorderRadius: CGFloat = 8
    var codeBlockPadding: CGFloat = 16

    var blockquoteBorderWidth: CGFloat = 3
    var blockquoteGapWidth: CGFloat = 16
    var blockquoteBorderColor: UIColor = UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1)
    var blockquoteBackgroundColor: UIColor = UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1)

    init(styleConfig: MarkdownStyleConfig) {
        applyCodeBlockStyle(from: styleConfig.codeBlock)
        applyBlockquoteStyle(from: styleConfig.blockquote)
    }

    private mutating func applyCodeBlockStyle(from style: CodeBlockStyle) {
        if let color = style.backgroundColor {
            codeBlockBackgroundColor = color
        }
        if let color = style.borderColor {
            codeBlockBorderColor = color
        }
        if let width = style.borderWidth {
            codeBlockBorderWidth = width
        }
        if let radius = style.borderRadius {
            codeBlockBorderRadius = radius
        }
        if let padding = style.padding {
            codeBlockPadding = padding
        }
    }

    private mutating func applyBlockquoteStyle(from style: BlockquoteStyle) {
        if let width = style.borderWidth {
            blockquoteBorderWidth = width
        }
        if let gap = style.gapWidth {
            blockquoteGapWidth = gap
        }
        if let color = style.borderColor {
            blockquoteBorderColor = color
        }
        if let color = style.backgroundColor {
            blockquoteBackgroundColor = color
        }
    }
}
