import UIKit

/// Checked-item text decoration, shared by ListItemRenderer (initial render)
/// and TaskListInteraction (in-place toggle) so a toggle produces exactly
/// what a fresh render of the toggled source would.
enum TaskListDecoration {
    /// Skips attachments and color-preserving runs (links, inline code).
    static func apply(
        to output: NSMutableAttributedString,
        range: NSRange,
        textColor: UIColor?,
        strikethrough: Bool,
        baseColor: UIColor
    ) {
        guard textColor != nil || strikethrough else { return }
        let strikethroughColor = textColor ?? baseColor
        output.enumerateAttributes(in: range, options: []) { attrs, runRange, _ in
            guard attrs[.attachment] == nil else { return }
            if strikethrough {
                output.addAttribute(
                    .strikethroughStyle,
                    value: NSUnderlineStyle.single.rawValue,
                    range: runRange
                )
                output.addAttribute(.strikethroughColor, value: strikethroughColor, range: runRange)
            }
            if let textColor, !RenderContext.shouldPreserveColors(attrs) {
                output.addAttribute(.foregroundColor, value: textColor, range: runRange)
            }
        }
    }

    static func remove(
        from output: NSMutableAttributedString,
        range: NSRange,
        baseColor: UIColor
    ) {
        output.enumerateAttributes(in: range, options: []) { attrs, runRange, _ in
            guard attrs[.attachment] == nil else { return }
            output.removeAttribute(.strikethroughStyle, range: runRange)
            output.removeAttribute(.strikethroughColor, range: runRange)
            if !RenderContext.shouldPreserveColors(attrs) {
                output.addAttribute(.foregroundColor, value: baseColor, range: runRange)
            }
        }
    }
}
