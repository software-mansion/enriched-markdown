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
        layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight,
        codeBlockLayout: MarkdownCodeBlockLayout = .wrapping
    ) -> NSAttributedString {
        render(
            markdown,
            config: config,
            options: options,
            imageRequestHeaders: imageRequestHeaders,
            plugins: [],
            writingDirection: writingDirection,
            layoutDirection: layoutDirection,
            codeBlockLayout: codeBlockLayout
        )
    }

    package static func render(
        _ markdown: String,
        config: MarkdownStyleConfiguration,
        options: MarkdownParsingOptions,
        imageRequestHeaders: [String: String],
        plugins: [any MarkdownRenderPlugin],
        writingDirection: MarkdownWritingDirection = .firstStrong,
        layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight,
        codeBlockLayout: MarkdownCodeBlockLayout = .wrapping
    ) -> NSAttributedString {
        let renderer = AttributedRenderer(
            config: config,
            imageRequestHeaders: imageRequestHeaders,
            plugins: plugins,
            writingDirection: writingDirection,
            layoutDirection: layoutDirection,
            codeBlockLayout: codeBlockLayout
        )
        return renderer.renderRoot(parse(markdown, options: effectiveParsingOptions(options, plugins: plugins)))
    }

    static func render(_ markdown: String, inputs: MarkdownRenderInputs) -> NSAttributedString {
        let options = effectiveParsingOptions(inputs.options, plugins: inputs.plugins.values)
        return AttributedRenderer(inputs: inputs).renderRoot(parse(markdown, options: options))
    }

    package static func parse(_ markdown: String, options: MarkdownParsingOptions) -> MarkdownASTNode {
        SourceOffsetAnnotator.annotate(Parser.shared.parseMarkdown(markdown, options: options), source: markdown)
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
