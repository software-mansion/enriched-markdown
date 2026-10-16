@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.math

import android.content.Context
import android.view.View
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginBlockSegment
import com.swmansion.enriched.markdown.plugin.PluginEventSink
import com.swmansion.enriched.markdown.plugin.PluginSegmentPayload
import com.swmansion.enriched.markdown.renderer.latexSourceOf
import com.swmansion.enriched.markdown.segments.SegmentViewConfig
import com.swmansion.enriched.markdown.styles.StyleConfig
import io.ratex.RaTeXFontLoader
import io.ratex.RaTeXRenderer

/** A display equation, laid out on the render thread. Core signs the segment with [latex]. */
class MathSegmentPayload internal constructor(
  val latex: String,
  /** Null when the engine rejected [latex]. */
  internal val renderer: RaTeXRenderer?,
) : PluginSegmentPayload {
  override val signatureSource: String get() = latex
}

/**
 * Display math standing on its own: core gives it a segment of its own, and this gives that
 * segment a [MathContainerView].
 */
class MathBlockSegment : PluginBlockSegment<MathSegmentPayload> {
  /**
   * Lays out here rather than in the view; RaTeX's own async API runs the same parse off the main
   * thread. A failure is reported here too, so it is reported again for every new document, as an
   * inline one is. Returns null for half-arrived content, which core then renders as text.
   */
  override fun renderPayload(
    node: MarkdownASTNode,
    style: StyleConfig,
    context: Context,
    onPluginEvent: PluginEventSink?,
  ): MathSegmentPayload? {
    val latex = latexSourceOf(node)
    if (latex.isBlank()) return null

    val mathStyle = style.mathStyle(context)
    val renderer =
      runRaTeX(
        onFailure = { error -> onPluginEvent?.emit(LatexError(latex, error.message, displayMode = true)) },
      ) {
        RaTeXFontLoader.ensureLoaded(context)
        val displayList = DisplayListCache.shared.get(latex, displayMode = true, color = mathStyle.color)
        RaTeXRenderer(displayList, mathStyle.fontSize) { RaTeXFontLoader.getTypeface(it) }
      }
    return MathSegmentPayload(latex, renderer)
  }

  override fun createView(
    payload: MathSegmentPayload,
    config: SegmentViewConfig,
  ): View =
    MathContainerView(config.context, config.style, config.selectionMenuConfig).apply {
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
