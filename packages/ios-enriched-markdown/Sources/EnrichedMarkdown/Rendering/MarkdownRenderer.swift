import UIKit

public enum MarkdownRenderer {
    public static func render(
        _ markdown: String,
        config: MarkdownStyleConfig,
        flags: Md4cFlags = .commonMark
    ) -> NSAttributedString {
        let ast = Parser.shared.parseMarkdown(markdown, flags: flags)
        let renderer = AttributedRenderer(config: config)
        return renderer.renderRoot(ast)
    }
}
