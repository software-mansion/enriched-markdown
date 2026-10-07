import EnrichedMarkdown
import SwiftUI
import UIKit

struct SyntaxHighlightingPlugin: MarkdownRenderPlugin {
    var defaultTheme: MarkdownTheme? { .syntaxHighlightingDefault }

    func styleCodeBlock(
        in output: NSMutableAttributedString,
        range: NSRange,
        language: String,
        config: MarkdownStyleConfiguration
    ) {
        let colors = config.syntaxHighlight.colors
        guard !colors.isEmpty else { return }

        let code = output.mutableString.substring(with: range)
        for token in SyntaxHighlighter.tokens(in: code, language: language) {
            guard let color = colors[token.type], NSMaxRange(token.range) <= range.length else { continue }
            output.addAttribute(
                .foregroundColor,
                value: color,
                range: NSRange(location: range.location + token.range.location, length: token.range.length)
            )
        }
    }
}

public extension View {
    /// Colors fenced code blocks by their info string's language; `false` turns it back off for a subtree.
    func markdownSyntaxHighlighting(_ isEnabled: Bool = true) -> some View {
        transformEnvironment(\.markdownRenderPlugins) { plugins in
            plugins.removeAll { $0 is SyntaxHighlightingPlugin }
            if isEnabled {
                plugins.append(SyntaxHighlightingPlugin())
            }
        }
    }
}

public extension MarkdownRenderer {
    /// `MarkdownRenderer.render` with syntax highlighting; resolve `config` with `.syntaxHighlightingDefault` among its layers.
    static func renderSyntaxHighlighted(
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
            plugins: [SyntaxHighlightingPlugin()],
            writingDirection: writingDirection,
            layoutDirection: layoutDirection
        )
    }
}
