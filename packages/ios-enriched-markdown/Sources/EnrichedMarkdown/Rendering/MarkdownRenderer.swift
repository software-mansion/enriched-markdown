import UIKit

public enum MarkdownRenderer {
    public static func render(
        _ markdown: String,
        config: MarkdownStyleConfig,
        flags: Md4cFlags = .commonMark,
        imageRequestHeaders: [String: String] = [:]
    ) -> NSAttributedString {
        let ast = Parser.shared.parseMarkdown(markdown, flags: flags)
        let renderer = AttributedRenderer(config: config, imageRequestHeaders: imageRequestHeaders)
        return renderer.renderRoot(ast)
    }
}
