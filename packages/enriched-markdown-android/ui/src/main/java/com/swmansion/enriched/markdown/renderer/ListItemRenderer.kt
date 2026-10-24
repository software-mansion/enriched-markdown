package com.swmansion.enriched.markdown.renderer

import android.text.SpannableStringBuilder
import android.text.style.ForegroundColorSpan
import android.text.style.StrikethroughSpan
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.BaseListSpan
import com.swmansion.enriched.markdown.spans.CodeBlockSpan
import com.swmansion.enriched.markdown.spans.OrderedListSpan
import com.swmansion.enriched.markdown.spans.TaskListSpan
import com.swmansion.enriched.markdown.spans.UnorderedListSpan
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_LIST_ITEM

class ListItemRenderer(
  private val config: RendererConfig,
) : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    val styleContext = factory.blockStyleContext
    val start = builder.length
    val listType = styleContext.listType ?: return

    val isTask = node.attributes["isTask"] == "true"
    val isChecked = isTask && node.attributes["taskChecked"] == "true"

    if (listType == BlockStyleContext.ListType.ORDERED) {
      styleContext.incrementListItemNumber()
    }

    // Claimed before the children render so nested task items take the later
    // indices, matching the top-down order of `- [ ]` markers in the source.
    val taskIndex = if (isTask) styleContext.taskItemCount++ else -1

    val depth = styleContext.listDepth - 1
    val listStyle = config.style.listStyle

    fun makeSpan(drawsMarker: Boolean): BaseListSpan =
      if (isTask) {
        TaskListSpan(
          taskStyle = config.style.taskListStyle,
          listStyle = listStyle,
          depth = depth,
          context = factory.context,
          styleCache = factory.styleCache,
          taskIndex = taskIndex,
          isChecked = isChecked,
          drawsMarker = drawsMarker,
          ancestorMarkerOffset = styleContext.ancestorMarkerOffset,
          markerExtraWidth = styleContext.listMarkerExtra,
          parentMarkerWidth = styleContext.listItemMarkerWidth,
        )
      } else {
        when (listType) {
          BlockStyleContext.ListType.UNORDERED -> {
            UnorderedListSpan(
              listStyle,
              depth,
              factory.context,
              factory.styleCache,
              drawsMarker,
              ancestorMarkerOffset = styleContext.ancestorMarkerOffset,
              parentMarkerWidth = styleContext.listItemMarkerWidth,
            )
          }

          BlockStyleContext.ListType.ORDERED -> {
            OrderedListSpan(
              listStyle,
              depth,
              factory.context,
              factory.styleCache,
              drawsMarker,
              markerExtraWidth = styleContext.listMarkerExtra,
              ancestorMarkerOffset = styleContext.ancestorMarkerOffset,
              parentMarkerWidth = styleContext.listItemMarkerWidth,
            ).apply {
              setItemNumber(styleContext.listItemNumber)
            }
          }
        }
      }

    val markerSpan = makeSpan(drawsMarker = true)

    // Nested lists inside this item shift by its extra marker width and measure their indent from its column.
    // Code blocks inside it start at its text column, since the item's spans leave their lines (see below).
    val previousMarkerExtra = styleContext.listItemMarkerExtra
    styleContext.listItemMarkerExtra = markerSpan.markerExtraWidth
    val previousMarkerWidth = styleContext.listItemMarkerWidth
    styleContext.listItemMarkerWidth = markerSpan.baselineMarkerWidth
    val previousIndent = styleContext.accumulatedIndent
    styleContext.accumulatedIndent = previousIndent + markerSpan.getLeadingMargin(false)
    try {
      factory.renderChildren(node, builder, onLinkPress, onLinkLongPress)
    } finally {
      styleContext.accumulatedIndent = previousIndent
      styleContext.listItemMarkerExtra = previousMarkerExtra
      styleContext.listItemMarkerWidth = previousMarkerWidth
    }

    if (builder.length == start || builder.substring(start).isBlank()) return

    if (builder.last() != '\n') {
      builder.append("\n")
    }

    val itemEnd = builder.length

    val codeBlocks = builder.getSpans(start, itemEnd, CodeBlockSpan::class.java)
    // Nested items render first, so a code block keeps the innermost item that holds it.
    for (block in codeBlocks) {
      if (block.listItem == null) block.listItem = markerSpan
    }

    val codeBlockRanges =
      codeBlocks
        .map { builder.getSpanStart(it) to builder.getSpanEnd(it) }
        .filter { it.first < it.second }
        .sortedBy { it.first }

    var segmentStart = start
    var isFirstSegment = true
    for ((codeStart, codeEnd) in codeBlockRanges) {
      if (segmentStart < codeStart) {
        builder.setSpan(
          if (isFirstSegment) markerSpan else makeSpan(drawsMarker = false),
          segmentStart,
          codeStart,
          SPAN_FLAGS_LIST_ITEM,
        )
        isFirstSegment = false
      }
      segmentStart = maxOf(segmentStart, codeEnd)
    }
    if (segmentStart < itemEnd) {
      builder.setSpan(
        if (isFirstSegment) markerSpan else makeSpan(drawsMarker = false),
        segmentStart,
        itemEnd,
        SPAN_FLAGS_LIST_ITEM,
      )
    }

    if (isChecked) {
      applyCheckedDecorations(builder, start, itemEnd, depth)
    }
  }

  private fun applyCheckedDecorations(
    builder: SpannableStringBuilder,
    itemStart: Int,
    itemEnd: Int,
    itemDepth: Int,
  ) {
    val taskStyle = config.style.taskListStyle
    val checkedTextColor = taskStyle.checkedTextColor
    val strikethrough = taskStyle.checkedStrikethrough

    if (checkedTextColor == 0 && !strikethrough) return

    val excludedRanges =
      (
        builder.getSpans(itemStart, itemEnd, BaseListSpan::class.java).filter { it.depth > itemDepth } +
          builder.getSpans(itemStart, itemEnd, CodeBlockSpan::class.java).toList()
      ).map { builder.getSpanStart(it) to builder.getSpanEnd(it) }
        .sortedBy { it.first }

    var currentPos = itemStart

    for ((start, end) in excludedRanges) {
      if (start > currentPos) {
        applyDecorationSpans(builder, currentPos, start, checkedTextColor, strikethrough)
      }
      currentPos = maxOf(currentPos, end)
    }

    if (currentPos < itemEnd) {
      applyDecorationSpans(builder, currentPos, itemEnd, checkedTextColor, strikethrough)
    }
  }

  private fun applyDecorationSpans(
    builder: SpannableStringBuilder,
    start: Int,
    end: Int,
    color: Int,
    strikethrough: Boolean,
  ) {
    if (color != 0) {
      builder.setSpan(ForegroundColorSpan(color), start, end, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
    }
    if (strikethrough) {
      builder.setSpan(StrikethroughSpan(), start, end, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
    }
  }
}
