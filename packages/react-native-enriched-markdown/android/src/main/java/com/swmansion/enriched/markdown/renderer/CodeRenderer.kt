package com.swmansion.enriched.markdown.renderer

import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.CodeBackgroundSpan
import com.swmansion.enriched.markdown.spans.CodeSpan
import com.swmansion.enriched.markdown.utils.text.DirectionControlSpan
import com.swmansion.enriched.markdown.utils.text.PROSE_DIRECTION
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE

class CodeRenderer(
  private val config: RendererConfig,
) : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    if (node.children.isEmpty() || node.children.all { it.content.isEmpty() }) return

    // writingDirection="word-majority": isolate inline code LTR so `fetch()` inside an RTL
    // line doesn't read as `()fetch`.
    val isolate = node.attributes[PROSE_DIRECTION] != null
    if (isolate) appendDirectionControl(builder, '\u2066')
    factory.renderWithSpan(builder, { node.children.forEach { builder.append(it.content) } }) { start, end, blockStyle ->
      builder.setSpan(
        CodeSpan(factory.styleCache, blockStyle),
        start,
        end,
        SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
      )
      builder.setSpan(
        CodeBackgroundSpan(config.style),
        start,
        end,
        SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
      )
    }
    if (isolate) appendDirectionControl(builder, '\u2069')
  }

  private fun appendDirectionControl(
    builder: SpannableStringBuilder,
    control: Char,
  ) {
    builder.append(control)
    builder.setSpan(DirectionControlSpan(), builder.length - 1, builder.length, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
  }
}
