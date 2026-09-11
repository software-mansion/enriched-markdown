import UIKit

/// Hides `||spoiler||` text. Runs as a post-pass over the rendered document
/// so wrappers rendered after the spoiler (`**||x||**`, `[||x||](url)`) are
/// covered, and again after a task-list toggle recolors an item at runtime.
enum SpoilerConcealment {
    private static let colorKeys: [NSAttributedString.Key] = [.foregroundColor, .underlineColor, .strikethroughColor]

    static func conceal(_ output: NSMutableAttributedString, in range: NSRange) {
        output.enumerateAttribute(MarkdownAttribute.spoiler, in: range) { value, spoilerRange, _ in
            guard MarkdownAttributeValue.boolValue(from: value) else { return }
            output.enumerateAttributes(in: spoilerRange, options: []) { attrs, runRange, _ in
                // Merge: a task toggle recolors runs that are already concealed.
                var stash = attrs[MarkdownAttribute.spoilerOriginalColors] as? [NSAttributedString.Key: UIColor] ?? [:]
                var changes: [NSAttributedString.Key: Any] = [:]
                for key in colorKeys {
                    guard let color = attrs[key] as? UIColor, color != .clear else { continue }
                    stash[key] = color
                    changes[key] = UIColor.clear
                }
                if !changes.isEmpty {
                    changes[MarkdownAttribute.spoilerOriginalColors] = stash
                }
                if let link = attrs[.link] {
                    changes[MarkdownAttribute.spoilerLink] = link
                    output.removeAttribute(.link, range: runRange)
                }
                output.addAttributes(changes, range: runRange)
            }
        }
    }

    /// The spoiler attribute flips to `false` rather than going away, so Copy
    /// as Markdown still emits the `||` markers.
    static func reveal(_ output: NSMutableAttributedString, in range: NSRange) {
        output.enumerateAttribute(MarkdownAttribute.spoiler, in: range) { value, spoilerRange, _ in
            guard MarkdownAttributeValue.boolValue(from: value) else { return }
            output.addAttribute(MarkdownAttribute.spoiler, value: false, range: spoilerRange)
            output.enumerateAttribute(MarkdownAttribute.spoilerOriginalColors, in: spoilerRange) { stash, runRange, _ in
                guard let stash = stash as? [NSAttributedString.Key: UIColor] else { return }
                output.addAttributes(stash, range: runRange)
                output.removeAttribute(MarkdownAttribute.spoilerOriginalColors, range: runRange)
            }
            output.enumerateAttribute(MarkdownAttribute.spoilerLink, in: spoilerRange) { link, runRange, _ in
                guard let link else { return }
                output.addAttribute(.link, value: link, range: runRange)
                output.removeAttribute(MarkdownAttribute.spoilerLink, range: runRange)
            }
        }
    }
}
