package com.swmansion.enriched.markdown.math

import com.swmansion.enriched.markdown.plugin.PluginEvent

/**
 * A LaTeX expression the engine could not render, shown as its raw source instead. [source] is the
 * whole failing expression without its `$`/`$$` delimiters, [message] the engine's error when it
 * gave one, and [displayMode] is `false` for inline `$...$` and `true` for block `$$...$$`.
 *
 * A data class on purpose: core deduplicates events per view by equality, so streamed content that
 * re-renders the same broken expression on every token still reports it once.
 */
data class LatexErrorEvent(
  val source: String,
  val message: String?,
  val displayMode: Boolean,
  override val pluginId: String = LatexMathPlugin.ID,
) : PluginEvent
