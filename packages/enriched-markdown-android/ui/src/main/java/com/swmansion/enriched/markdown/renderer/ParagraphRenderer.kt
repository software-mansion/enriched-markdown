package com.swmansion.enriched.markdown.renderer

import android.text.SpannableStringBuilder
import android.text.style.AlignmentSpan
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.styles.ParagraphStyle
import com.swmansion.enriched.markdown.utils.text.extensions.containsBlockImage
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import com.swmansion.enriched.markdown.utils.text.span.applyLineHeightSkippingImages
import com.swmansion.enriched.markdown.utils.text.span.applyMarginBottom
import com.swmansion.enriched.markdown.utils.text.span.applyMarginTop

class ParagraphRenderer(
  private val config: RendererConfig,
) : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    val context = factory.blockStyleContext

    // If nested (e.g., inside a list or blockquote), render content simply with a newline
    if (context.isInsideBlockElement()) {
      factory.renderChildren(node, builder, onLinkPress, onLinkLongPress)
      builder.append("\n")
      return
    }

    val start = builder.length
    val style = config.style.paragraphStyle

    context.setParagraphStyle(style)
    try {
      factory.renderChildren(node, builder, onLinkPress, onLinkLongPress)
    } finally {
      context.popBlockStyle()
    }

    if (builder.length > start) {
      builder.applySpans(node, style, start)
    }
  }

  private fun SpannableStringBuilder.applySpans(
    node: MarkdownASTNode,
    style: ParagraphStyle,
    start: Int,
  ) {
    val end = length

    // TODO: LineHeightSpan may also clip superscript/subscript glyphs that extend
    // outside the normal line bounds. A similar "skip" strategy as for images may
    // be needed here once super/subscript usage in practice is better understood.
    applyLineHeightSkippingImages(this, start, end, style.lineHeight)

    // Only apply AlignmentSpan for non-default alignments (Center/Right)
    if (style.textAlign.needsAlignmentSpan) {
      setSpan(
        AlignmentSpan.Standard(style.textAlign.layoutAlignment),
        start,
        end,
        SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
      )
    }

    val marginTop = if (node.containsBlockImage()) config.style.imageStyle.marginTop else style.marginTop
    applyMarginTop(this, start, marginTop)

    val marginBottom = if (node.containsBlockImage()) config.style.imageStyle.marginBottom else style.marginBottom
    applyMarginBottom(this, marginBottom)
  }
}
