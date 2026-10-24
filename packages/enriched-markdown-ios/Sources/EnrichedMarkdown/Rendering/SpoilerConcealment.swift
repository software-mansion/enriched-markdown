import UIKit

/// Hides `||spoiler||` text. Runs as a post-pass over the rendered document
/// so wrappers rendered after the spoiler (`**||x||**`, `[||x||](url)`) are
/// covered, and again after a task-list toggle recolors an item at runtime.
enum SpoilerConcealment {
    static func conceal(_ output: NSMutableAttributedString, in range: NSRange) {
        output.enumerateAttribute(MarkdownAttribute.spoiler, in: range) { value, spoilerRange, _ in
            guard MarkdownAttributeValue.boolValue(from: value) else { return }
            ColorConcealment.conceal(output, in: spoilerRange, stash: MarkdownAttribute.spoilerOriginalColors)
            output.enumerateAttribute(.link, in: spoilerRange) { link, runRange, _ in
                guard let link else { return }
                output.addAttribute(MarkdownAttribute.spoilerLink, value: link, range: runRange)
                output.removeAttribute(.link, range: runRange)
            }
        }
    }

    /// The spoiler attribute flips to `false` rather than going away, so Copy
    /// as Markdown still emits the `||` markers.
    static func reveal(_ output: NSMutableAttributedString, in range: NSRange) {
        output.enumerateAttribute(MarkdownAttribute.spoiler, in: range) { value, spoilerRange, _ in
            guard MarkdownAttributeValue.boolValue(from: value) else { return }
            output.addAttribute(MarkdownAttribute.spoiler, value: false, range: spoilerRange)
            ColorConcealment.reveal(output, in: spoilerRange, stash: MarkdownAttribute.spoilerOriginalColors)
            output.enumerateAttribute(MarkdownAttribute.spoilerLink, in: spoilerRange) { link, runRange, _ in
                guard let link else { return }
                output.addAttribute(.link, value: link, range: runRange)
                output.removeAttribute(MarkdownAttribute.spoilerLink, range: runRange)
            }
        }
    }
}
