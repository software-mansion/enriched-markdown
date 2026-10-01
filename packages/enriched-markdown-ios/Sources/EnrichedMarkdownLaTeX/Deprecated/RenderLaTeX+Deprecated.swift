import EnrichedMarkdown
import UIKit

// Shims for the 0.1 `flags:` label. Delete this file when they are removed.

public extension MarkdownRenderer {
    @available(*, deprecated, renamed: "renderLaTeX(_:config:options:imageRequestHeaders:accessibilityLabel:writingDirection:layoutDirection:)")
    static func renderLaTeX(
        _ markdown: String,
        config: MarkdownStyleConfiguration,
        flags: MarkdownParsingOptions,
        imageRequestHeaders: [String: String] = [:],
        accessibilityLabel: String = "Math: {speech}",
        writingDirection: MarkdownWritingDirection = .firstStrong,
        layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight
    ) -> NSAttributedString {
        renderLaTeX(
            markdown,
            config: config,
            options: flags,
            imageRequestHeaders: imageRequestHeaders,
            accessibilityLabel: accessibilityLabel,
            writingDirection: writingDirection,
            layoutDirection: layoutDirection
        )
    }

    @available(*, deprecated, renamed: "renderLaTeX(_:config:options:imageRequestHeaders:accessibilityLabel:writingDirection:layoutDirection:)")
    static func renderLaTeX(
        _ markdown: String,
        config: MarkdownStyleConfiguration,
        flags: MarkdownParsingOptions,
        imageRequestHeaders: [String: String] = [:],
        accessibilityLabel: @escaping (String) -> String,
        writingDirection: MarkdownWritingDirection = .firstStrong,
        layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight
    ) -> NSAttributedString {
        renderLaTeX(
            markdown,
            config: config,
            options: flags,
            imageRequestHeaders: imageRequestHeaders,
            accessibilityLabel: accessibilityLabel,
            writingDirection: writingDirection,
            layoutDirection: layoutDirection
        )
    }
}
