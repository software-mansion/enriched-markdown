@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.renderer

import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.spans.TextSpan
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE

/**
 * The latex a latex node carries. md4c hands it over either as the node's own content or split
 * across text children, with breaks that only mattered to the source layout.
 */
@InternalPluginApi
fun latexSourceOf(node: MarkdownASTNode): String {
  if (node.content.isNotEmpty()) return node.content
  return node.children.joinToString("") { child ->
    when (child.type) {
      MarkdownASTNode.NodeType.SoftBreak, MarkdownASTNode.NodeType.LineBreak -> " "
      else -> child.content
    }
  }
}

/**
 * Core's fallback for `$...$` and `$$...$$`: echoes the source, delimiters included, so a document
 * parsed with `Md4cFlags(latexMath = true)` still shows its equations - as text - when no math
 * plugin is installed. A plugin's registered renderer replaces it.
 */
internal class LatexSourceRenderer(
  private val isDisplay: Boolean,
) : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    val latex = latexSourceOf(node)
    if (latex.isEmpty()) return

    // Display math promoted to a top-level node has no enclosing block, so it becomes a paragraph
    // of its own: styled and spaced like one, rather than running into the next block.
    val blockStyle = factory.blockStyleContext.currentBlockStyleOrNull()
    if (blockStyle == null) {
      val paragraph = MarkdownASTNode(MarkdownASTNode.NodeType.Paragraph, children = listOf(node))
      factory.builtInRenderer(MarkdownASTNode.NodeType.Paragraph)?.render(paragraph, builder, onLinkPress, onLinkLongPress, factory)
      return
    }

    val delimiter = if (isDisplay) "$$" else "$"
    val start = builder.length
    builder.append(delimiter).append(latex).append(delimiter)
    builder.setSpan(
      TextSpan(blockStyle, factory.context),
      start,
      builder.length,
      SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
    )
  }
}
