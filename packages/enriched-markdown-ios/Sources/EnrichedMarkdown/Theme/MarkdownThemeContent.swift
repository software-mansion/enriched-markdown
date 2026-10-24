import UIKit

/// Themes are environment values, so their contents must be `Sendable`.
public protocol MarkdownThemeContent: Sendable {
    func apply(to config: inout MarkdownStyleConfiguration, traitCollection: UITraitCollection)
}

public struct MarkdownThemeGroup: MarkdownThemeContent {
    let contents: [any MarkdownThemeContent]

    public init(contents: [any MarkdownThemeContent]) {
        self.contents = contents
    }

    public func apply(to config: inout MarkdownStyleConfiguration, traitCollection: UITraitCollection) {
        for content in contents {
            content.apply(to: &config, traitCollection: traitCollection)
        }
    }
}
