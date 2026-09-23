import SwiftUI
import UIKit

// Shims for the 0.1 parsing API. Delete this file when they are removed.

@available(*, deprecated, renamed: "MarkdownParsingOptions")
public typealias Md4cFlags = MarkdownParsingOptions

public extension EnrichedMarkdownText {
    @available(*, deprecated, renamed: "init(_:options:)")
    init(_ markdown: String, flags: MarkdownParsingOptions) {
        self.init(markdown, options: flags)
    }
}

public extension MarkdownRenderer {
    @available(*, deprecated, renamed: "render(_:config:options:imageRequestHeaders:writingDirection:layoutDirection:)")
    static func render(
        _ markdown: String,
        config: MarkdownStyleConfiguration,
        flags: MarkdownParsingOptions,
        imageRequestHeaders: [String: String] = [:],
        writingDirection: MarkdownWritingDirection = .firstStrong,
        layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight
    ) -> NSAttributedString {
        render(
            markdown,
            config: config,
            options: flags,
            imageRequestHeaders: imageRequestHeaders,
            writingDirection: writingDirection,
            layoutDirection: layoutDirection
        )
    }
}

public extension Parser {
    @available(*, deprecated, renamed: "parseMarkdown(_:options:)")
    func parseMarkdown(_ markdown: String, flags: MarkdownParsingOptions) -> MarkdownASTNode {
        parseMarkdown(markdown, options: flags)
    }
}
