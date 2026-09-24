package com.swmansion.enriched.markdown.renderer

import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.HeadingSpan
import com.swmansion.enriched.markdown.utils.common.layout.isLayoutRTL
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import com.swmansion.enriched.markdown.utils.text.span.applyMarginBottom
import com.swmansion.enriched.markdown.utils.text.span.applyMarginTop
import com.swmansion.enriched.markdown.utils.text.span.applyTextAlignment
import com.swmansion.enriched.markdown.utils.text.span.createLineHeightSpan

class HeadingRenderer(
  private val config: RendererConfig,
) : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    val level = node.getAttribute("level")?.toIntOrNull() ?: 1
    val start = builder.length

    val headingStyle = config.style.headingStyles[level]!!
    val blockStyleContext = factory.blockStyleContext
    blockStyleContext.setHeadingStyle(headingStyle, level)

    try {
      factory.renderChildren(node, builder, onLinkPress, onLinkLongPress)
    } finally {
      blockStyleContext.popBlockStyle()
    }

    val end = builder.length
    val contentLength = end - start

    if (contentLength > 0) {
      builder.setSpan(
        HeadingSpan(
          level,
          config.style,
        ),
        start,
        end,
        SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
      )

      builder.setSpan(
        createLineHeightSpan(headingStyle.lineHeight),
        start,
        end,
        SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
      )

      applyTextAlignment(builder, start, end, headingStyle.textAlign, factory.context.resources.isLayoutRTL())

      applyMarginTop(builder, start, headingStyle.marginTop)
      applyMarginBottom(builder, headingStyle.marginBottom)
    }
  }
}
