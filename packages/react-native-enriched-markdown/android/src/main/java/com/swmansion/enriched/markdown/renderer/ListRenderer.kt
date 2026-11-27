package com.swmansion.enriched.markdown.renderer

import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.ListItemSpacingSpan
import com.swmansion.enriched.markdown.spans.MarginBottomSpan
import com.swmansion.enriched.markdown.spans.OrderedListSpan
import com.swmansion.enriched.markdown.styles.ListStyle
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_LINE_HEIGHT_PRIORITY
import com.swmansion.enriched.markdown.utils.text.span.applyLineHeightSkippingImages
import com.swmansion.enriched.markdown.utils.text.span.applyMarginTop

class ListRenderer(
  private val config: RendererConfig,
  private val isOrdered: Boolean,
) : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    val start = builder.length
    // The items after the first of a list already shown (TextRenderCache): no gap above them.
    val continuation = node.getAttribute(CONTINUATION_ATTRIBUTE) == "true"
    val listStyle = config.style.listStyle
    val listType = if (isOrdered) BlockStyleContext.ListType.ORDERED else BlockStyleContext.ListType.UNORDERED

    val startNumber = if (isOrdered) startNumber(node) else 1

    val markerExtraWidth = if (isOrdered) markerExtraWidth(node, listStyle, startNumber, factory) else 0f
    val contextManager = ListContextManager(factory.blockStyleContext)
    val entryState = contextManager.enterList(listType, listStyle, startNumber, markerExtraWidth)

    // For top-level lists, insert marginTop spacer before rendering content
    val topLevel = entryState.previousDepth == 0
    if (topLevel && !continuation) {
      applyMarginTop(builder, start, listStyle.marginTop)
    }

    // Track start index after the potential 1-character marginTop spacer
    val contentStart = if (topLevel && !continuation && listStyle.marginTop > 0) start + 1 else start

    // Ensure nested lists start on a new line if the parent hasn't provided one
    if (entryState.previousDepth > 0 && builder.isNotEmpty() && builder.last() != '\n') {
      builder.append("\n")
    }

    val styleContext = factory.blockStyleContext
    val itemStarts = styleContext.topLevelListItemStarts
    val itemTaskStarts = styleContext.topLevelListItemTaskStarts
    if (topLevel) {
      itemStarts.clear()
      itemTaskStarts.clear()
    }
    try {
      for (child in node.children) {
        if (topLevel) {
          itemStarts += builder.length
          itemTaskStarts += styleContext.taskItemCount
        }
        factory.renderNode(child, builder, onLinkPress, onLinkLongPress)
      }
    } finally {
      contextManager.exitList(entryState)
    }

    if (builder.length > contentStart) {
      applyListSpacing(builder, contentStart, entryState.previousDepth, listStyle, factory.blockStyleContext, itemStarts)
    }
  }

  /** Lists under 100 keep the `99.` column, so only numbers from 100 on widen it. Task items draw a checkbox. */
  private fun markerExtraWidth(
    node: MarkdownASTNode,
    listStyle: ListStyle,
    startNumber: Int,
    factory: RendererFactory,
  ): Float {
    val wideNumbers = mutableListOf<Int>()
    var number = startNumber
    for (item in node.children) {
      if (item.type != MarkdownASTNode.NodeType.ListItem) continue
      if (number >= 100 && item.attributes["isTask"] != "true") wideNumbers += number
      number++
    }
    return OrderedListSpan.measureExtraWidth(listStyle, factory.context, wideNumbers)
  }

  private fun applyListSpacing(
    builder: SpannableStringBuilder,
    start: Int,
    depth: Int,
    style: ListStyle,
    styleContext: BlockStyleContext,
    itemStarts: List<Int>,
  ) {
    // TODO: LineHeightSpan may also clip superscript/subscript glyphs that extend
    // outside the normal line bounds. A similar "skip" strategy as for images may
    // be needed here once super/subscript usage in practice is better understood.
    // Priority flag so the list's line height iterates before the children's
    // MarginBottomSpans in both the measuring StaticLayout and the TextView's copy
    // of the text (see SPAN_FLAGS_LINE_HEIGHT_PRIORITY). The span is added after the
    // children, so without the flag the two disagree on which runs last.
    //
    // A top-level list takes one per item, so the items of a list a stream grows render alike in
    // a render of the whole list and in one of its last items. A line never spans two items.
    if (depth == 0) {
      val end = builder.length
      itemStarts.forEachIndexed { i, from ->
        val to = itemStarts.getOrNull(i + 1) ?: end
        if (to > from) applyLineHeightSkippingImages(builder, from, to, style.lineHeight, SPAN_FLAGS_LINE_HEIGHT_PRIORITY)
      }
    } else {
      applyLineHeightSkippingImages(builder, start, builder.length, style.lineHeight, SPAN_FLAGS_LINE_HEIGHT_PRIORITY)
    }

    // Item spacing and external bottom margin are only handled by the root-level list
    if (depth == 0) {
      applyItemSpacing(builder, start, style.itemSpacing, styleContext)

      builder.append("\n")
      builder.setSpan(
        MarginBottomSpan(style.marginBottom),
        builder.length - 1,
        builder.length,
        SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
      )
    }
  }

  // Inserts the vertical gap between consecutive items (including nested ones)
  // by spanning the newline that precedes each item start. The first item of
  // the root list gets no spacing above it.
  private fun applyItemSpacing(
    builder: SpannableStringBuilder,
    start: Int,
    itemSpacing: Float,
    styleContext: BlockStyleContext,
  ) {
    if (itemSpacing <= 0f) return

    val itemStarts =
      styleContext.listItemStarts
        .filter { it in start until builder.length }
        .distinct()
        .sorted()

    for (itemStart in itemStarts.drop(1)) {
      builder.setSpan(
        ListItemSpacingSpan(itemSpacing),
        itemStart - 1,
        itemStart,
        SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
      )
    }
  }

  companion object {
    const val CONTINUATION_ATTRIBUTE = "enrmContinuation"

    /** The first number of an ordered list, as md4c reports it. */
    fun startNumber(list: MarkdownASTNode): Int = list.getAttribute("start")?.toIntOrNull()?.coerceAtLeast(0) ?: 1
  }
}
