package com.swmansion.enriched.markdown.math

import android.content.Context
import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.renderer.LatexSourceRenderer
import com.swmansion.enriched.markdown.renderer.NodeRenderer
import com.swmansion.enriched.markdown.renderer.RendererConfig
import com.swmansion.enriched.markdown.renderer.RendererFactory
import com.swmansion.enriched.markdown.renderer.latexSourceOf
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import io.ratex.RaTeXFontLoader

/**
 * Renders `$...$` - and mid-line `$$...$$` - into the spannable as a [MathInlineSpan].
 *
 * Runs on the render thread, so it only measures the text it is given and builds the span; the
 * equation itself is laid out later, during measure.
 */
class MathInlineRenderer(
  private val config: RendererConfig,
  private val context: Context,
) : NodeRenderer {
  /**
   * Core's own renderers for the two node types, kept for content with no equation in it: an
   * unterminated `$$` mid-stream has to reach the screen as the source it is, not disappear.
   */
  private val sourceFallbacks =
    mapOf(
      MarkdownASTNode.NodeType.LatexMathInline to LatexSourceRenderer(isDisplay = false),
      MarkdownASTNode.NodeType.LatexMathDisplay to LatexSourceRenderer(isDisplay = true),
    )

  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    val latex = latexSourceOf(node)
    if (latex.isBlank()) {
      sourceFallbacks[node.type]?.render(node, builder, onLinkPress, onLinkLongPress, factory)
      return
    }

    // Loads the KaTeX fonts here, on the render thread, so the span's first layout pass doesn't.
    // A failure is left to the span, which reports it and draws its own source instead.
    runRaTeX { RaTeXFontLoader.ensureLoaded(context) }

    // An inline equation sits on a line of the enclosing block and has to match its text. Display
    // math promoted to its own node has no enclosing block, so it falls back to the block style.
    val fontSize =
      factory.blockStyleContext.currentBlockStyleOrNull()?.fontSize
        ?: config.style.mathStyle(context).fontSize

    val start = builder.length
    builder.append(OBJECT_REPLACEMENT_CHARACTER)

    val span =
      MathInlineSpan(
        latex = latex,
        fontSize = fontSize,
        textColor = config.style.inlineMathStyle(context).color,
        onPluginEvent = config.onPluginEvent,
      )

    builder.setSpan(span, start, builder.length, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
  }

  private companion object {
    /** U+FFFC: one character for the equation to replace, so selection and export see a unit. */
    const val OBJECT_REPLACEMENT_CHARACTER = "\uFFFC"
  }
}
