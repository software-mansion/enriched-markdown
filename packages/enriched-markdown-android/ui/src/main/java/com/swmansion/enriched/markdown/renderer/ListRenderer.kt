package com.swmansion.enriched.markdown.renderer

import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.MarginBottomSpan
import com.swmansion.enriched.markdown.spans.OrderedListSpan
import com.swmansion.enriched.markdown.styles.ListStyle
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
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
    val listStyle = config.style.listStyle
    val listType = if (isOrdered) BlockStyleContext.ListType.ORDERED else BlockStyleContext.ListType.UNORDERED

    val contextManager = ListContextManager(factory.blockStyleContext)
    val entryState = contextManager.enterList(listType, listStyle)
    val styleContext = factory.blockStyleContext
    val previousMarkerWidth = styleContext.listMarkerWidth
    val previousMarkerOffset = styleContext.ancestorMarkerOffset
    if (entryState.previousDepth > 0) {
      styleContext.ancestorMarkerOffset += styleContext.listItemMarkerExtra
    }
    styleContext.listMarkerWidth = if (isOrdered) measureMarkerColumn(node, listStyle, factory) else 0f

    // For top-level lists, insert marginTop spacer before rendering content
    if (entryState.previousDepth == 0) {
      applyMarginTop(builder, start, listStyle.marginTop)
    }

    // Track start index after the potential 1-character marginTop spacer
    val contentStart = if (entryState.previousDepth == 0 && listStyle.marginTop > 0) start + 1 else start

    // Ensure nested lists start on a new line if the parent hasn't provided one
    if (entryState.previousDepth > 0 && builder.isNotEmpty() && builder.last() != '\n') {
      builder.append("\n")
    }

    try {
      factory.renderChildren(node, builder, onLinkPress, onLinkLongPress)
    } finally {
      styleContext.listMarkerWidth = previousMarkerWidth
      styleContext.ancestorMarkerOffset = previousMarkerOffset
      contextManager.exitList(entryState)
    }

    if (builder.length > contentStart) {
      applyListSpacing(builder, contentStart, entryState.previousDepth, listStyle)
    }
  }

  /** Widest marker this list draws; lists under 100 items keep the `99.` column. */
  private fun measureMarkerColumn(
    node: MarkdownASTNode,
    listStyle: ListStyle,
    factory: RendererFactory,
  ): Float {
    val marker = OrderedListSpan(listStyle, 0, factory.context, factory.styleCache)
    var number = 1
    var width = marker.measureMarkerWidth(99)
    for (item in node.children) {
      if (item.type != MarkdownASTNode.NodeType.ListItem) continue
      if (number >= 100 && item.attributes["isTask"] != "true") {
        width = maxOf(width, marker.measureMarkerWidth(number))
      }
      number++
    }
    return width
  }

  private fun applyListSpacing(
    builder: SpannableStringBuilder,
    start: Int,
    depth: Int,
    style: com.swmansion.enriched.markdown.styles.BaseBlockStyle,
  ) {
    // TODO: LineHeightSpan may also clip superscript/subscript glyphs that extend
    // outside the normal line bounds. A similar "skip" strategy as for images may
    // be needed here once super/subscript usage in practice is better understood.
    applyLineHeightSkippingImages(builder, start, builder.length, style.lineHeight)

    // External bottom margin is only handled by the root-level list
    if (depth == 0) {
      builder.append("\n")
      builder.setSpan(
        MarginBottomSpan(style.marginBottom),
        builder.length - 1,
        builder.length,
        SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
      )
    }
  }
}
