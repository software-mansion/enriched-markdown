import UIKit

final class ListItemRenderer: NodeRenderer {
    private let factory: RendererFactory
    private let config: MarkdownStyleConfig

    init(factory: RendererFactory, config: MarkdownStyleConfig) {
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

        let startLocation = output.length
        factory.renderChildren(of: node, into: output, context: context)
        ParagraphStyleHelpers.ensureTrailingNewline(in: output)

        let itemRange = NSRange(location: startLocation, length: output.length - startLocation)
        guard itemRange.length > 0 else { return }

        let baseMarkerWidth = isTask
            ? effectiveTaskMarkerWidth(for: context.listType)
            : effectiveMarkerWidth(for: context.listType)
        let gapWidth = max(config.list.gapWidth ?? 12, 4)
        let marginLeft = config.list.marginLeft ?? 24
        let blockquoteIndent = CGFloat(context.blockquoteDepth) * blockquoteLevelSpacing()
        let totalIndent = blockquoteIndent + baseMarkerWidth + gapWidth + (CGFloat(nestingLevel) * marginLeft)
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
            totalIndent: totalIndent,
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

    private func effectiveMarkerWidth(for listType: ListType) -> CGFloat {
        let minWidth = config.list.markerMinWidth ?? 0
        switch listType {
        case .ordered:
            return max(minWidth, 20)
        case .unordered:
            return max(minWidth, config.list.bulletSize ?? 6)
        }
    }

    /// The checkbox column is at least as wide as the list type's normal
    /// marker column, so task items align with their non-task siblings.
    private func effectiveTaskMarkerWidth(for listType: ListType) -> CGFloat {
        max(effectiveMarkerWidth(for: listType), config.taskList.checkboxSize ?? 14)
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
        totalIndent: CGFloat,
        lineHeight: CGFloat
    ) {
        let string = output.string as NSString
        var location = itemRange.location
        let end = NSMaxRange(itemRange)

        while location < end {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            let applyRange = NSIntersectionRange(paragraphRange, itemRange)
            guard applyRange.length > 0 else { break }

            if shouldSkipListStyling(in: output, range: applyRange, nestingLevel: nestingLevel) {
                location = NSMaxRange(applyRange)
                continue
            }

            let style = NSMutableParagraphStyle()
            style.firstLineHeadIndent = totalIndent
            style.headIndent = totalIndent

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

            location = NSMaxRange(applyRange)
        }
    }

    private func shouldSkipListStyling(
        in output: NSMutableAttributedString,
        range: NSRange,
        nestingLevel: Int
    ) -> Bool {
        if let depth = MarkdownAttributeValue.intValue(
            from: output.attribute(MarkdownAttribute.listDepth, at: range.location, effectiveRange: nil)
        ), depth > nestingLevel {
            return true
        }

        if MarkdownAttributeValue.boolValue(
            from: output.attribute(MarkdownAttribute.codeBlock, at: range.location, effectiveRange: nil)
        ) {
            return true
        }

        return false
    }
}
