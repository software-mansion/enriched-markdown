import UIKit

struct BlockDecorationConfig {
    var codeBlockBackgroundColor: UIColor = UIColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1)
    var codeBlockBorderColor: UIColor = UIColor(red: 0.22, green: 0.25, blue: 0.29, alpha: 1)
    var codeBlockBorderWidth: CGFloat = 1
    var codeBlockBorderRadius: CGFloat = 8
    var codeBlockPadding: CGFloat = 16

    init(styleConfig: MarkdownStyleConfig) {
        if let color = styleConfig.codeBlock.backgroundColor {
            codeBlockBackgroundColor = color
        }
        if let color = styleConfig.codeBlock.borderColor {
            codeBlockBorderColor = color
        }
        if let width = styleConfig.codeBlock.borderWidth {
            codeBlockBorderWidth = width
        }
        if let radius = styleConfig.codeBlock.borderRadius {
            codeBlockBorderRadius = radius
        }
        if let padding = styleConfig.codeBlock.padding {
            codeBlockPadding = padding
        }
    }
}
