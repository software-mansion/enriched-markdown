package com.swmansion.enriched.markdown.renderer

import android.graphics.Paint
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.LineHeightSpan
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.BlockquoteSpan
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_CONTAINER_BACKGROUND
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import com.swmansion.enriched.markdown.utils.text.span.applyLineHeightSkippingImages
import com.swmansion.enriched.markdown.utils.text.span.applyMarginBottom
import com.swmansion.enriched.markdown.utils.text.span.applyMarginTop

class BlockquoteRenderer(
  private val config: RendererConfig,
) : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    if (builder.isNotEmpty() && builder.last() != '\n') {
      builder.append("\n")
    }

    val start = builder.length
    val style = config.style.blockquoteStyle
    val context = factory.blockStyleContext
    val depth = context.blockquoteDepth

    // Track depth to handle nested indentation levels
    context.blockquoteDepth = depth + 1
    context.setBlockquoteStyle(style)

    try {
      factory.renderChildren(node, builder, onLinkPress, onLinkLongPress)
    } finally {
      context.popBlockStyle()
      context.blockquoteDepth = depth
    }

    if (builder.length == start) return
    val end = builder.length

    // Find immediately nested quotes to exclude them from this level's line-height/margins
    val nestedRanges =
      builder
        .getSpans(start, end, BlockquoteSpan::class.java)
        .filter { it.depth == depth + 1 }
        .map { builder.getSpanStart(it) to builder.getSpanEnd(it) }
        .sortedBy { it.first }

    // The accent bar span covers the full range for visual continuity.
    // SPAN_FLAGS_CONTAINER_BACKGROUND keeps the blockquote fill under any
    // inline chip/pill backgrounds on the same line.
    builder.setSpan(
      BlockquoteSpan(style, depth, factory.context, factory.styleCache),
      start,
      end,
      SPAN_FLAGS_CONTAINER_BACKGROUND,
    )

    // Apply line height only to segments that are NOT nested quotes, skipping
    // block images so their expanded line metrics aren't re-clamped
    applyLineHeightExcludingNested(builder, nestedRanges, start, end, style.lineHeight)

    // Nested quotes pad their own box to match web CSS
    if (style.padding > 0) {
      builder.setSpan(
        BlockquoteBoundaryPaddingSpan(style.padding.toInt()),
        start,
        end,
        SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
      )
    }

    // Margins are only applied by the outermost (root) quote
    if (depth == 0) {
      applyMarginTop(builder, start, style.marginTop)
      applyMarginBottom(builder, style.marginBottom)
    }
  }

  /**
   * Internal span to handle top/bottom padding by modifying font metrics.
   * Same approach as the code block boundary padding span.
   */
  private class BlockquoteBoundaryPaddingSpan(
    private val padding: Int,
  ) : LineHeightSpan {
    override fun chooseHeight(
      text: CharSequence,
      startLine: Int,
      endLine: Int,
      spanstartv: Int,
      v: Int,
      fm: Paint.FontMetricsInt,
    ) {
      if (text !is Spanned) return

      val spanStart = text.getSpanStart(this)
      val spanEnd = text.getSpanEnd(this)

      if (startLine == spanStart) {
        fm.ascent -= padding
        fm.top -= padding
      }

      val isLastLine = endLine == spanEnd || (spanEnd <= endLine && text[spanEnd - 1] == '\n')
      if (isLastLine) {
        fm.descent += padding
        fm.bottom += padding
      }
    }
  }

  private fun applyLineHeightExcludingNested(
    builder: SpannableStringBuilder,
    nestedRanges: List<Pair<Int, Int>>,
    start: Int,
    end: Int,
    lineHeight: Float,
  ) {
    var currentPos = start
    for ((nestedStart, nestedEnd) in nestedRanges) {
      if (currentPos < nestedStart) {
        applyLineHeightSkippingImages(builder, currentPos, nestedStart, lineHeight)
      }
      currentPos = nestedEnd
    }
    if (currentPos < end) {
      applyLineHeightSkippingImages(builder, currentPos, end, lineHeight)
    }
  }
}
