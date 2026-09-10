import EnrichedMarkdown
import UIKit

/// Resolved `MathBlock()` values for root-level display math; nil inherits
/// from the surrounding paragraph (font size, color, margins) or means none
/// (background, padding).
struct MathBlockStyle: PluginStyle {
    var fontSize: CGFloat?
    var foregroundColor: UIColor?
    var backgroundColor: UIColor?
    var padding: CGFloat?
    var marginTop: CGFloat?
    var marginBottom: CGFloat?
    var textAlignment: NSTextAlignment?

    mutating func merge(_ other: MathBlockStyle) {
        fontSize = other.fontSize ?? fontSize
        foregroundColor = other.foregroundColor ?? foregroundColor
        backgroundColor = other.backgroundColor ?? backgroundColor
        padding = other.padding ?? padding
        marginTop = other.marginTop ?? marginTop
        marginBottom = other.marginBottom ?? marginBottom
        textAlignment = other.textAlignment ?? textAlignment
    }
}

/// Resolved `InlineMath()` values; nil inherits the surrounding text color.
struct InlineMathStyle: PluginStyle {
    var foregroundColor: UIColor?

    mutating func merge(_ other: InlineMathStyle) {
        foregroundColor = other.foregroundColor ?? foregroundColor
    }
}

extension MarkdownStyleConfig {
    var mathBlock: MathBlockStyle {
        get { pluginStyles[MathBlockStyle.self] ?? MathBlockStyle() }
        set { pluginStyles[MathBlockStyle.self] = newValue }
    }

    var inlineMath: InlineMathStyle {
        get { pluginStyles[InlineMathStyle.self] ?? InlineMathStyle() }
        set { pluginStyles[InlineMathStyle.self] = newValue }
    }
}
