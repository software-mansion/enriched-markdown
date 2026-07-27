package com.swmansion.enriched.markdown.renderer

import android.content.Context
import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.MathInlineSpan
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import io.ratex.RaTeXFontLoader

class MathInlineRenderer(
  private val config: RendererConfig,
  private val context: Context,
) : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    RaTeXFontLoader.ensureLoaded(context)

    val latex = extractLatex(node)
    if (latex.isEmpty()) return

    val blockStyle = factory.blockStyleContext.requireBlockStyle()

    val start = builder.length
    builder.append("\uFFFC")
    val end = builder.length

    val span =
      MathInlineSpan(
        context = context,
        latex = latex,
        fontSize = blockStyle.fontSize,
        textColor = config.style.inlineMathStyle.color,
      )

    builder.setSpan(span, start, end, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
  }

  private fun extractLatex(node: MarkdownASTNode): String {
    if (node.content.isNotEmpty()) return node.content
    return node.children.joinToString("") { child ->
      when (child.type) {
        MarkdownASTNode.NodeType.SoftBreak, MarkdownASTNode.NodeType.LineBreak -> " "
        else -> child.content
      }
    }
  }
}
