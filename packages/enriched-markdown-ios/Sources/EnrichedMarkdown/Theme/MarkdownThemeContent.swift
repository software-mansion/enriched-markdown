import UIKit

public protocol MarkdownThemeContent {
    func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection)
}

public struct MarkdownThemeGroup: MarkdownThemeContent, Sendable {
    let contents: [any MarkdownThemeContent]

    public init(contents: [any MarkdownThemeContent]) {
        self.contents = contents
    }

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        for content in contents {
            content.apply(to: &config, traitCollection: traitCollection)
        }
    }
}
