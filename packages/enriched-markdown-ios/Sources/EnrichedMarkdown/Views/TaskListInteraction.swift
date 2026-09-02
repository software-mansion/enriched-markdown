import UIKit

/// Hit-testing, in-place toggling, and source rewriting for GFM task-list
/// checkboxes, mirroring the React Native package's TaskListTapUtils:
/// the whole leading margin of the checkbox paragraph is tappable.
enum TaskListInteraction {
    struct Hit {
        let index: Int
        let checked: Bool
        let itemText: String
    }

    /// Finds the task item whose checkbox margin contains `point` (in text
    /// container coordinates). `checked` reports the state before any toggle.
    static func hitTest(
        point: CGPoint,
        attributedText: NSAttributedString,
        textLayoutManager: NSTextLayoutManager?,
        containerWidth: CGFloat
    ) -> Hit? {
        guard attributedText.length > 0,
              let textLayoutManager,
              let contentManager = textLayoutManager.textContentManager,
              let fragment = textLayoutManager.textLayoutFragment(for: point),
              let paragraphRange = TextLayoutHelpers.nsRange(fragment.rangeInElement, in: contentManager),
              paragraphRange.location < attributedText.length
        else { return nil }

        let attrs = attributedText.attributes(at: paragraphRange.location, effectiveRange: nil)
        guard let checkedValue = attrs[MarkdownAttribute.taskListItem],
              let index = MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.taskListIndex])
        else { return nil }

        let style = attrs[.paragraphStyle] as? NSParagraphStyle
        let checkboxZone = style?.firstLineHeadIndent ?? 0
        if TextLayoutHelpers.paragraphIsRTL(style) {
            guard point.x > containerWidth - checkboxZone else { return nil }
        } else {
            guard point.x < checkboxZone else { return nil }
        }

        return Hit(
            index: index,
            checked: MarkdownAttributeValue.boolValue(from: checkedValue),
            itemText: itemText(in: attributedText, index: index)
        )
    }

    /// The first line of the item's checkbox paragraph, trimmed.
    static func itemText(in attributedText: NSAttributedString, index: Int) -> String {
        var anchorRange: NSRange?
        attributedText.enumerateAttribute(
            MarkdownAttribute.taskListIndex,
            in: NSRange(location: 0, length: attributedText.length)
        ) { value, range, stop in
            if MarkdownAttributeValue.intValue(from: value) == index {
                anchorRange = range
                stop.pointee = true
            }
        }
        guard let anchorRange else { return "" }

        let string = attributedText.string as NSString
        var lineRange = anchorRange
        let newline = string.range(of: "\n", options: [], range: anchorRange)
        if newline.location != NSNotFound {
            lineRange.length = newline.location - anchorRange.location
        }
        return string.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A copy of `attributedText` with the item's checkbox state and
    /// checked-text decoration updated in place — no re-parse, so a tap
    /// redraws immediately. Nil when no item carries `index`.
    static func togglingItem(
        in attributedText: NSAttributedString,
        index: Int,
        checked: Bool,
        config: MarkdownStyleConfig
    ) -> NSAttributedString? {
        var itemRanges: [NSRange] = []
        attributedText.enumerateAttribute(
            MarkdownAttribute.taskListIndex,
            in: NSRange(location: 0, length: attributedText.length)
        ) { value, range, _ in
            if MarkdownAttributeValue.intValue(from: value) == index {
                itemRanges.append(range)
            }
        }
        guard !itemRanges.isEmpty else { return nil }

        let result = NSMutableAttributedString(attributedString: attributedText)
        let baseColor = config.list.foregroundColor ?? UIColor.label
        let checkedTextColor = checked ? config.taskList.checkedTextColor : nil
        let checkedStrikethrough = checked && (config.taskList.checkedStrikethrough ?? false)

        for range in itemRanges {
            result.enumerateAttribute(MarkdownAttribute.taskListItem, in: range) { value, anchorRange, _ in
                guard value != nil else { return }
                result.addAttribute(
                    MarkdownAttribute.taskListItem,
                    value: NSNumber(value: checked),
                    range: anchorRange
                )
            }
            if checked {
                TaskListDecoration.apply(
                    to: result,
                    range: range,
                    textColor: checkedTextColor,
                    strikethrough: checkedStrikethrough,
                    baseColor: baseColor
                )
            } else {
                TaskListDecoration.remove(from: result, range: range, baseColor: baseColor)
            }
        }
        return result
    }

    /// The marker pattern matches the React Native package's, so source
    /// indices line up with the renderer's document-order task indices.
    private static let taskMarkerRegex = try? NSRegularExpression(
        pattern: "^([ \\t]*[-*+][ \\t]+)\\[[ xX]\\]",
        options: [.anchorsMatchLines]
    )

    /// Rewrites the `index`-th task marker in the markdown source.
    static func togglingSource(_ markdown: String, index: Int, checked: Bool) -> String {
        guard index >= 0, let regex = taskMarkerRegex else { return markdown }

        let nsMarkdown = markdown as NSString
        let matches = regex.matches(in: markdown, range: NSRange(location: 0, length: nsMarkdown.length))
        guard index < matches.count else { return markdown }

        let match = matches[index]
        let prefix = nsMarkdown.substring(with: match.range(at: 1))
        return nsMarkdown.replacingCharacters(in: match.range, with: "\(prefix)[\(checked ? "x" : " ")]")
    }
}
