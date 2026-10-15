import UIKit

final class ListItemRenderer: NodeRenderer {
    private let factory: RendererFactory
    private let config: MarkdownStyleConfiguration

    init(factory: RendererFactory, config: MarkdownStyleConfiguration) {
        self.factory = factory
        self.config = config
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        context.listItemNumber += 1
        let currentPosition = context.listItemNumber
        let currentDepth = context.listDepth
        let nestingLevel = currentDepth - 1
        let isTask = node.attribute("isTask") == "true"
        let isChecked = isTask && node.attribute("taskChecked") == "true"
        // Claimed before rendering children so indices follow document order.
        let taskIndex = context.taskItemIndex
        if isTask {
            context.taskItemIndex += 1
        }

        let baseMarkerWidth = isTask
            ? effectiveTaskMarkerWidth(in: context)
            : effectiveMarkerWidth(in: context)
        // How far a widened ordered list grew this item's own column; nested lists move by it.
        let markerExtra = baseMarkerWidth - defaultColumnWidth(isTask: isTask, listType: context.listType)

        let startLocation = output.length
        let prevMarkerExtra = context.listItemMarkerExtra
        context.listItemMarkerExtra = markerExtra
        factory.renderChildren(of: node, into: output, context: context)
        context.listItemMarkerExtra = prevMarkerExtra
        ParagraphStyleHelpers.ensureTrailingNewline(in: output)

        let itemRange = NSRange(location: startLocation, length: output.length - startLocation)
        guard itemRange.length > 0 else { return }

        let gapWidth = max(config.list.gapWidth ?? 12, 4)
        let marginLeading = config.list.marginLeading ?? 24
        let blockquoteIndent = CGFloat(context.blockquoteDepth) * blockquoteLevelSpacing()
        let totalIndent = blockquoteIndent + baseMarkerWidth + gapWidth + (CGFloat(nestingLevel) * marginLeading)
            + context.listMarkerOffset
        let lineHeight = config.list.lineHeight ?? 0

        let metadata: [NSAttributedString.Key: Any] = [
            MarkdownAttribute.listDepth: nestingLevel,
            MarkdownAttribute.listType: context.listType.rawValue,
            MarkdownAttribute.listItemNumber: currentPosition
        ]

        applyListItemStyling(
            to: output,
            itemRange: itemRange,
            nestingLevel: nestingLevel,
            metadata: metadata,
            indents: ItemIndents(
                text: totalIndent,
                quote: totalIndent - context.listMarkerOffset,
                markerExtra: markerExtra
            ),
            lineHeight: lineHeight
        )

        if isTask {
            applyTaskItemStyling(
                to: output,
                itemRange: itemRange,
                nestingLevel: nestingLevel,
                isChecked: isChecked,
                taskIndex: taskIndex
            )
        }
    }

    /// An ordered list's column is sized to its widest number by `ListRenderer`.
    private func effectiveMarkerWidth(in context: RenderContext) -> CGFloat {
        context.listType == .ordered
            ? context.listMarkerWidth
            : Self.defaultMarkerWidth(for: .unordered, config: config)
    }

    /// The item's column before an ordered list widens it for its numbers.
    private func defaultColumnWidth(isTask: Bool, listType: ListType) -> CGFloat {
        let markerWidth = Self.defaultMarkerWidth(for: listType, config: config)
        return isTask ? max(markerWidth, config.taskList.checkboxSize ?? 14) : markerWidth
    }

    /// The marker column before an ordered list widens it for its numbers.
    static func defaultMarkerWidth(for listType: ListType, config: MarkdownStyleConfiguration) -> CGFloat {
        let minWidth = config.list.markerMinWidth ?? 0
        switch listType {
        case .ordered:
            return max(minWidth, 20)
        case .unordered:
            return max(minWidth, config.list.bulletSize ?? 6)
        }
    }

    /// The checkbox column is at least as wide as the list's marker column,
    /// so task items align with their non-task siblings.
    private func effectiveTaskMarkerWidth(in context: RenderContext) -> CGFloat {
        max(effectiveMarkerWidth(in: context), config.taskList.checkboxSize ?? 14)
    }

    private func blockquoteLevelSpacing() -> CGFloat {
        (config.blockquote.borderWidth ?? 3) + (config.blockquote.gapWidth ?? 16)
    }

    /// Marks the item's own paragraphs (not nested children) with the task
    /// attributes — the first one anchors the checkbox, every one carries the
    /// item index — and applies the checked-item text decoration when
    /// configured.
    private func applyTaskItemStyling(
        to output: NSMutableAttributedString,
        itemRange: NSRange,
        nestingLevel: Int,
        isChecked: Bool,
        taskIndex: Int
    ) {
        let checkedTextColor = isChecked ? config.taskList.checkedTextColor : nil
        let checkedStrikethrough = isChecked && (config.taskList.checkedStrikethrough ?? false)

        let string = output.string as NSString
        var location = itemRange.location
        let end = NSMaxRange(itemRange)
        var markedCheckboxAnchor = false

        while location < end {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            let applyRange = NSIntersectionRange(paragraphRange, itemRange)
            guard applyRange.length > 0 else { break }
            location = NSMaxRange(applyRange)

            if shouldSkipListStyling(in: output, range: applyRange, nestingLevel: nestingLevel) {
                continue
            }

            output.addAttribute(MarkdownAttribute.taskListIndex, value: taskIndex, range: applyRange)

            if !markedCheckboxAnchor {
                markedCheckboxAnchor = true
                output.addAttribute(
                    MarkdownAttribute.taskListItem,
                    value: NSNumber(value: isChecked),
                    range: applyRange
                )
            }

            TaskListDecoration.apply(
                to: output,
                range: applyRange,
                textColor: checkedTextColor,
                strikethrough: checkedStrikethrough,
                baseColor: config.list.foregroundColor ?? UIColor.label
            )
        }
    }

    private func applyListItemStyling(
        to output: NSMutableAttributedString,
        itemRange: NSRange,
        nestingLevel: Int,
        metadata: [NSAttributedString.Key: Any],
        indents: ItemIndents,
        lineHeight: CGFloat
    ) {
        let string = output.string as NSString
        var location = itemRange.location
        let end = NSMaxRange(itemRange)

        while location < end {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            let applyRange = NSIntersectionRange(paragraphRange, itemRange)
            guard applyRange.length > 0 else { break }
            location = NSMaxRange(applyRange)

            if output.attribute(MarkdownAttribute.blockquoteDepth, at: applyRange.location, effectiveRange: nil) != nil {
                shiftQuoteParagraph(in: output, range: applyRange, indents: indents)
                continue
            }
            if shouldSkipListStyling(in: output, range: applyRange, nestingLevel: nestingLevel) {
                continue
            }

            let style = NSMutableParagraphStyle()
            style.firstLineHeadIndent = indents.text
            style.headIndent = indents.text

            if lineHeight > 0 {
                style.minimumLineHeight = lineHeight
                style.maximumLineHeight = lineHeight
            }

            var attributes = metadata
            attributes[.paragraphStyle] = style
            output.addAttributes(attributes, range: applyRange)

            if lineHeight > 0 {
                ParagraphStyleHelpers.applyBaselineOffset(to: output, range: applyRange)
            }
        }
    }

    /// A quote inside the item keeps its own attributes and indent, moved
    /// into the item's text column together with its bars. The bars also keep
    /// the marker widening of any list item between this one and the quote.
    private func shiftQuoteParagraph(in output: NSMutableAttributedString, range: NSRange, indents: ItemIndents) {
        let innerExtra = output.attribute(MarkdownAttribute.blockquoteMarkerExtra, at: range.location, effectiveRange: nil)
            as? CGFloat ?? 0
        let style = ParagraphStyleHelpers.getOrCreateParagraphStyle(in: output, at: range.location)
        style.firstLineHeadIndent += indents.quote
        style.headIndent += indents.quote
        output.addAttributes(
            [
                .paragraphStyle: style,
                MarkdownAttribute.blockquoteBarOffset: indents.quote + innerExtra,
                MarkdownAttribute.blockquoteMarkerExtra: innerExtra + indents.markerExtra
            ],
            range: range
        )
    }

    /// Nested lists, code blocks, quotes, and spacer lines are not the
    /// item's own text.
    private func shouldSkipListStyling(
        in output: NSMutableAttributedString,
        range: NSRange,
        nestingLevel: Int
    ) -> Bool {
        let attrs = output.attributes(at: range.location, effectiveRange: nil)
        if let depth = MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.listDepth]), depth > nestingLevel {
            return true
        }
        if MarkdownAttributeValue.boolValue(from: attrs[MarkdownAttribute.codeBlock]) || attrs[.attachment] is CodeBlockAttachment {
            return true
        }
        if attrs[MarkdownAttribute.blockquoteDepth] != nil {
            return true
        }
        // Read in place: bridging `output.string` copies the document.
        return output.mutableString.rangeOfCharacter(
            from: ParagraphStyleHelpers.nonNewlines,
            options: [],
            range: range
        ).location == NSNotFound
    }
}

/// Where a list item moves its own paragraphs and the quotes inside it.
private struct ItemIndents {
    let text: CGFloat
    /// Each enclosing item shifts a quote too, adding its own widened column then.
    let quote: CGFloat
    /// How far a widened ordered list grew this item's marker column.
    let markerExtra: CGFloat
}
