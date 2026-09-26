package com.swmansion.enriched.markdown.renderer

import android.text.SpannableStringBuilder
import android.text.TextPaint
import android.text.style.ReplacementSpan
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.LinkPillSpan
import com.swmansion.enriched.markdown.spans.LinkSpan
import com.swmansion.enriched.markdown.utils.text.extensions.applyBlockStyleFont
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE

class LinkRenderer(
  private val config: RendererConfig,
) : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    val url = node.getAttribute("url") ?: return

    factory.renderWithSpan(builder, { factory.renderChildren(node, builder, onLinkPress, onLinkLongPress) }) { start, end, blockStyle ->
      val variant = factory.styleCache.resolvedVariantForUrl(url)
      if (variant?.pill == true && builder.getSpans(start, end, ReplacementSpan::class.java).isEmpty()) {
        val fontFamily = variant.fontFamily.ifEmpty { factory.styleCache.linkFontFamily }.ifEmpty { blockStyle.fontFamily }
        val font = TextPaint().apply { applyBlockStyleFont(blockStyle.copy(fontFamily = fontFamily), factory.context) }
        factory.registerDeferredSpan(
          LinkPillSpan(
            variant,
            font.typeface,
            blockStyle.fontSize,
            builder.subSequence(start, end).toString(),
            factory.context,
          ),
          start,
          end,
        )
      }
      builder.setSpan(
        LinkSpan(url, onLinkPress, onLinkLongPress, factory.styleCache, blockStyle, factory.context),
        start,
        end,
        SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
      )
    }
  }
}
