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
    val latex = extractLatex(node)
    if (latex.isEmpty()) return

    // Loads the KaTeX fonts here, on the render thread, so the span's first layout pass doesn't.
    RaTeXFontLoader.ensureLoaded(context)

    val fontSize =
      factory.blockStyleContext.currentBlockStyleOrNull()?.fontSize
        ?: config.style.mathStyle.fontSize

    val start = builder.length
    builder.append("￼")

    val span =
      MathInlineSpan(
        context = context,
        latex = latex,
        fontSize = fontSize,
        textColor = config.style.inlineMathStyle.color,
        onLatexError = config.onLatexError,
      )

    builder.setSpan(span, start, builder.length, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
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
