import UIKit

public enum MarkdownRenderer {
    /// `layoutDirection` is what `.firstStrong` paragraphs without a strong
    /// character follow; pass the hosting view's resolved direction.
    public static func render(
        _ markdown: String,
        config: MarkdownStyleConfig,
        flags: Md4cFlags = .commonMark,
        imageRequestHeaders: [String: String] = [:],
        writingDirection: MarkdownWritingDirection = .firstStrong,
        layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight
    ) -> NSAttributedString {
        render(
            markdown,
            config: config,
            flags: flags,
            imageRequestHeaders: imageRequestHeaders,
            plugins: [],
            writingDirection: writingDirection,
            layoutDirection: layoutDirection
        )
    }

    package static func render(
        _ markdown: String,
        config: MarkdownStyleConfig,
        flags: Md4cFlags,
        imageRequestHeaders: [String: String],
        plugins: [any MarkdownRenderPlugin],
        writingDirection: MarkdownWritingDirection = .firstStrong,
        layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight
    ) -> NSAttributedString {
        let ast = Parser.shared.parseMarkdown(markdown, flags: effectiveFlags(flags, plugins: plugins))
        let annotated = SourceOffsetAnnotator.annotate(ast, source: markdown)
        let renderer = AttributedRenderer(
            config: config,
            imageRequestHeaders: imageRequestHeaders,
            plugins: plugins,
            writingDirection: writingDirection,
            layoutDirection: layoutDirection
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
