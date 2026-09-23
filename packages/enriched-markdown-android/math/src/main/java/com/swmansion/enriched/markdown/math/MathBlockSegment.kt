@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.math

import android.content.Context
import android.view.View
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.plugin.BlockSegmentPlugin
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginSegmentPayload
import com.swmansion.enriched.markdown.segments.SegmentViewConfig
import com.swmansion.enriched.markdown.styles.StyleConfig

/** The latex core signs a display-math segment with, and the view lays out. */
data class MathSegmentPayload(
  val latex: String,
) : PluginSegmentPayload {
  override val signatureSource: String get() = latex
}

/**
 * Display math standing on its own: core gives it a segment of its own, and this gives that
 * segment a [MathContainerView].
 *
 * The latex is only extracted here; it is parsed in the view, on the main thread.
 */
class MathBlockSegment : BlockSegmentPlugin {
  /**
   * Returns null for anything with no equation in it - half-arrived streamed content, say - which
   * makes core render the node as text instead, so its source still reaches the screen.
   */
  override fun renderPayload(
    node: MarkdownASTNode,
    style: StyleConfig,
    context: Context,
  ): PluginSegmentPayload? {
    val latex = latexOf(node)
    if (latex.isBlank()) return null
    return MathSegmentPayload(latex)
  }

  override fun createView(
    payload: PluginSegmentPayload,
    config: SegmentViewConfig,
  ): View =
    MathContainerView(config.context, config.style).apply {
      selectionMenuConfig = config.selectionMenuConfig
      onPluginEvent = config.onPluginEvent
      applyLatex((payload as MathSegmentPayload).latex)
    }

  override fun updateView(
    view: View,
    payload: PluginSegmentPayload,
    config: SegmentViewConfig,
  ) {
    (view as MathContainerView).applyLatex((payload as MathSegmentPayload).latex)
  }

  override fun matchesView(view: View): Boolean = view is MathContainerView

  /**
   * A display-math node carries its equation either as its own content or as a single text child,
   * depending on how the parser reached it.
   */
  private fun latexOf(node: MarkdownASTNode): String =
    if (node.children.isNotEmpty()) {
      node.children.first().content
    } else {
      node.content
    }
}
