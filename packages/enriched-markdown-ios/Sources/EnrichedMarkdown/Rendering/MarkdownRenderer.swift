import UIKit

public enum MarkdownRenderer {
    /// `layoutDirection` is what `.firstStrong` paragraphs without a strong
    /// character follow; pass the hosting view's resolved direction.
    public static func render(
        _ markdown: String,
        config: MarkdownStyleConfiguration,
        options: MarkdownParsingOptions = .commonMark,
        imageRequestHeaders: [String: String] = [:],
        writingDirection: MarkdownWritingDirection = .firstStrong,
        layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight
    ) -> NSAttributedString {
        render(
            markdown,
            config: config,
            options: options,
            imageRequestHeaders: imageRequestHeaders,
            plugins: [],
            writingDirection: writingDirection,
            layoutDirection: layoutDirection
        )
    }

    package static func render(
        _ markdown: String,
        config: MarkdownStyleConfiguration,
        options: MarkdownParsingOptions,
        imageRequestHeaders: [String: String],
        plugins: [any MarkdownRenderPlugin],
        writingDirection: MarkdownWritingDirection = .firstStrong,
        layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight
    ) -> NSAttributedString {
        let ast = Parser.shared.parseMarkdown(markdown, options: effectiveParsingOptions(options, plugins: plugins))
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

    /// `options` after every plugin's adjustments — what the document is
    /// parsed with, and what a copied slice must be re-parsed with.
    package static func effectiveParsingOptions(
        _ options: MarkdownParsingOptions,
        plugins: [any MarkdownRenderPlugin]
    ) -> MarkdownParsingOptions {
        var adjusted = options
        for plugin in plugins {
            plugin.adjustParsingOptions(&adjusted)
        }
        return adjusted
    }
}
