import UIKit

/// Hides `||spoiler||` text by making its foreground transparent and stashing
/// the color it had for the reveal. Runs as a post-pass over the rendered
/// document so wrappers rendered after the spoiler (`**||x||**`,
/// `[||x||](url)`) are covered, and again after a task-list toggle recolors
/// an item at runtime.
enum SpoilerConcealment {
    /// Conceals every spoiler run in `range` that is not already transparent.
    static func conceal(_ output: NSMutableAttributedString, in range: NSRange) {
        output.enumerateAttribute(MarkdownAttribute.spoiler, in: range) { value, spoilerRange, _ in
            guard MarkdownAttributeValue.boolValue(from: value) else { return }
            output.enumerateAttributes(in: spoilerRange, options: []) { attrs, runRange, _ in
                if let color = attrs[.foregroundColor] as? UIColor, color != .clear {
                    output.addAttribute(MarkdownAttribute.spoilerOriginalColor, value: color, range: runRange)
                }
                output.addAttribute(.foregroundColor, value: UIColor.clear, range: runRange)
            }
        }
    }

    /// Shows the concealed runs in `range` in their stashed color. The spoiler
    /// attribute flips to `false` rather than going away, so Copy as Markdown
    /// still emits the `||` markers.
    static func reveal(_ output: NSMutableAttributedString, in range: NSRange) {
        output.enumerateAttribute(MarkdownAttribute.spoiler, in: range) { value, spoilerRange, _ in
            guard MarkdownAttributeValue.boolValue(from: value) else { return }
            output.addAttribute(MarkdownAttribute.spoiler, value: false, range: spoilerRange)
            output.enumerateAttribute(MarkdownAttribute.spoilerOriginalColor, in: spoilerRange) { color, runRange, _ in
                guard let color else { return }
                output.addAttribute(.foregroundColor, value: color, range: runRange)
                output.removeAttribute(MarkdownAttribute.spoilerOriginalColor, range: runRange)
            }
        }
    }
}
