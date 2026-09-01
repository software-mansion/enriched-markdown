import UIKit

public enum MarkdownRenderer {
    public static func render(
        _ markdown: String,
        config: MarkdownStyleConfig,
        flags: Md4cFlags = .commonMark,
        imageRequestHeaders: [String: String] = [:]
    ) -> NSAttributedString {
        render(
            markdown,
            config: config,
            flags: flags,
            imageRequestHeaders: imageRequestHeaders,
            plugins: []
        )
    }

    package static func render(
        _ markdown: String,
        config: MarkdownStyleConfig,
        flags: Md4cFlags,
        imageRequestHeaders: [String: String],
        plugins: [any MarkdownRenderPlugin]
    ) -> NSAttributedString {
        var effectiveFlags = flags
        for plugin in plugins {
            plugin.adjustFlags(&effectiveFlags)
        }
        let ast = Parser.shared.parseMarkdown(markdown, flags: effectiveFlags)
        let annotated = SourceOffsetAnnotator.annotate(ast, source: markdown)
        let renderer = AttributedRenderer(
            config: config,
            imageRequestHeaders: imageRequestHeaders,
            plugins: plugins
        )
        return renderer.renderRoot(annotated)
    }
}
