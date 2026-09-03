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
        let ast = Parser.shared.parseMarkdown(markdown, flags: effectiveFlags(flags, plugins: plugins))
        let annotated = SourceOffsetAnnotator.annotate(ast, source: markdown)
        let renderer = AttributedRenderer(
            config: config,
            imageRequestHeaders: imageRequestHeaders,
            plugins: plugins
        )
        return renderer.renderRoot(annotated)
    }

    /// `flags` after every plugin's adjustments — what the document is
    /// parsed with, and what a copied slice must be re-parsed with.
    package static func effectiveFlags(
        _ flags: Md4cFlags,
        plugins: [any MarkdownRenderPlugin]
    ) -> Md4cFlags {
        var adjusted = flags
        for plugin in plugins {
            plugin.adjustFlags(&adjusted)
        }
        return adjusted
    }
}
