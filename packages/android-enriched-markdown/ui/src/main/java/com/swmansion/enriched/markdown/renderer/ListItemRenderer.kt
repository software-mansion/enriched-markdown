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

    factory.renderChildren(node, builder, onLinkPress, onLinkLongPress)

    if (builder.length == start || builder.substring(start).isBlank()) return

    while (builder.length > start && builder.last() == '\n') {
      builder.delete(builder.length - 1, builder.length)
    }
    builder.append("\n")

    val depth = styleContext.listDepth - 1
    val listStyle = config.style.listStyle
    val itemEnd = builder.length
    val span =
      if (isTask) {
        TaskListSpan(
          taskStyle = config.style.taskListStyle,
          listStyle = listStyle,
          depth = depth,
          context = factory.context,
          styleCache = factory.styleCache,
          isChecked = isChecked,
        )
      } else {
        when (listType) {
          BlockStyleContext.ListType.UNORDERED -> {
            UnorderedListSpan(listStyle, depth, factory.context, factory.styleCache)
          }

          BlockStyleContext.ListType.ORDERED -> {
            OrderedListSpan(listStyle, depth, factory.context, factory.styleCache).apply {
              setItemNumber(styleContext.listItemNumber)
            }
          }
        }
      }

    builder.setSpan(span, start, itemEnd, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)

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
