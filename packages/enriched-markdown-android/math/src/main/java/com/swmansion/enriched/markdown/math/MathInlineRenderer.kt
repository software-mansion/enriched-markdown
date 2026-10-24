@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.math

import android.content.Context
import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.renderer.NodeRenderer
import com.swmansion.enriched.markdown.renderer.RendererConfig
import com.swmansion.enriched.markdown.renderer.RendererFactory
import com.swmansion.enriched.markdown.renderer.latexSourceOf
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import io.ratex.RaTeXFontLoader

/** Renders `$...$` - and mid-line `$$...$$` - into the spannable as a [MathInlineSpan]. */
class MathInlineRenderer(
  private val config: RendererConfig,
  private val context: Context,
) : NodeRenderer {
  // One renderer serves one render, so the style is resolved once rather than per equation.
  private val blockFontSize by lazy { config.style.mathStyle(context).fontSize }
  private val textColor = config.style.inlineMathStyle().color

  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    val latex = latexSourceOf(node)
    if (latex.isBlank()) {
      // An unterminated `$$` mid-stream: core shows it as source instead of dropping it.
      renderSource(node, builder, onLinkPress, onLinkLongPress, factory)
      return
    }

    // A failure is left to layOut, which reports it.
    runRaTeX { RaTeXFontLoader.ensureLoaded(context) }

    // An inline equation sits on a line of the enclosing block and has to match its text. Display
    // math promoted to its own node has no enclosing block, so it falls back to the block style.
    val fontSize =
      factory.blockStyleContext.currentBlockStyleOrNull()?.fontSize
        ?: blockFontSize

    val span =
      MathInlineSpan.layOut(
        latex = latex,
        fontSize = fontSize,
        textColor = textColor,
        displayMode = node.type == MarkdownASTNode.NodeType.LatexMathDisplay,
        onPluginEvent = config.onPluginEvent,
      )
    if (span == null) {
      renderSource(node, builder, onLinkPress, onLinkLongPress, factory)
      return
    }

    val start = builder.length
    builder.append(OBJECT_REPLACEMENT_CHARACTER)
    builder.setSpan(span, start, builder.length, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
  }

  private fun renderSource(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    factory.builtInRenderer(node.type)?.render(node, builder, onLinkPress, onLinkLongPress, factory)
  }

  private companion object {
    /** U+FFFC: one character for the equation to replace, so selection and export see a unit. */
    const val OBJECT_REPLACEMENT_CHARACTER = "￼"
  }
}
