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
 *
 * Whitespace against the delimiters is dropped: it is the line breaks of a `$$` block written on
 * lines of its own, which TeX ignores but which would otherwise follow the source into error
 * events, copies and the plain-text fallback.
 */
@InternalPluginApi
fun latexSourceOf(node: MarkdownASTNode): String = trimLatex(untrimmedLatexSourceOf(node))

private fun untrimmedLatexSourceOf(node: MarkdownASTNode): String =
  node.content.ifEmpty {
    node.children.joinToString("") { child ->
      when (child.type) {
        MarkdownASTNode.NodeType.SoftBreak, MarkdownASTNode.NodeType.LineBreak -> " "
        else -> child.content
      }
    }
  }

/** [String.trim], except that it keeps the space of a trailing control space (`\ `), which TeX typesets. */
private fun trimLatex(source: String): String {
  val trimmed = source.trim()
  if (trimmed.length == source.length || !trimmed.endsWith('\\')) return trimmed
  val trailingBackslashes = trimmed.length - trimmed.trimEnd('\\').length
  return if (trailingBackslashes % 2 == 1) "$trimmed " else trimmed
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
    // A blank equation - a `$$` just opened mid-stream, say - is still shown rather than dropped.
    val latex = latexSourceOf(node).ifEmpty { untrimmedLatexSourceOf(node) }
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
