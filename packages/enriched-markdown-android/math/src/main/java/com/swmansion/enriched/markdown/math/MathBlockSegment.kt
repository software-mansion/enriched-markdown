@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.math

import android.content.Context
import android.view.View
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.plugin.BlockSegmentPlugin
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginSegmentPayload
import com.swmansion.enriched.markdown.renderer.latexSourceOf
import com.swmansion.enriched.markdown.segments.SegmentViewConfig
import com.swmansion.enriched.markdown.styles.StyleConfig
import io.ratex.DisplayList
import io.ratex.RaTeXEngine
import io.ratex.RaTeXFontLoader

/** A display equation, parsed on the render thread. Core signs the segment with [latex]. */
class MathSegmentPayload internal constructor(
  val latex: String,
  /** Null when the engine rejected [latex]. */
  internal val displayList: DisplayList?,
  internal val failure: Throwable?,
) : PluginSegmentPayload {
  override val signatureSource: String get() = latex
}

/**
 * Display math standing on its own: core gives it a segment of its own, and this gives that
 * segment a [MathContainerView].
 */
class MathBlockSegment : BlockSegmentPlugin<MathSegmentPayload> {
  /**
   * Parses here rather than in the view; RaTeX's own async API runs the same parse off the main
   * thread. Returns null for half-arrived content, which core then renders as text.
   */
  override fun renderPayload(
    node: MarkdownASTNode,
    style: StyleConfig,
    context: Context,
  ): MathSegmentPayload? {
    val latex = latexSourceOf(node)
    if (latex.isBlank()) return null

    var failure: Throwable? = null
    val displayList =
      runRaTeX(onFailure = { failure = it }) {
        RaTeXFontLoader.ensureLoaded(context)
        RaTeXEngine.parseBlocking(latex, displayMode = true, color = style.mathStyle(context).color)
      }
    return MathSegmentPayload(latex, displayList, failure)
  }

  override fun createView(
    payload: MathSegmentPayload,
    config: SegmentViewConfig,
  ): View =
    MathContainerView(config.context, config.style, config.selectionMenuConfig, config.onPluginEvent).apply {
      applyPayload(payload)
    }

  override fun updateView(
    view: View,
    payload: MathSegmentPayload,
    config: SegmentViewConfig,
  ) {
    (view as MathContainerView).apply {
      selectionMenuConfig = config.selectionMenuConfig
      applyPayload(payload)
    }
  }

  override fun matchesView(view: View): Boolean = view is MathContainerView
}
