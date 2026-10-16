import EnrichedMarkdown
import UIKit

struct SyntaxHighlightStyle: PluginStyle {
    var colors: [SyntaxTokenType: UIColor] = [:]

    mutating func merge(_ other: SyntaxHighlightStyle) {
        colors.merge(other.colors) { _, new in new }
    }
}

extension MarkdownStyleConfiguration {
    var syntaxHighlight: SyntaxHighlightStyle {
        get { pluginStyles[SyntaxHighlightStyle.self] ?? SyntaxHighlightStyle() }
        set { pluginStyles[SyntaxHighlightStyle.self] = newValue }
    }
}
