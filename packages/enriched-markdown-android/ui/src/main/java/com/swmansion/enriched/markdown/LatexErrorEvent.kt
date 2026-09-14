package com.swmansion.enriched.markdown

/**
 * Payload for a LaTeX expression the engine could not render, shown as its raw
 * source instead. [source] is the whole failing expression without its `$`/`$$`
 * delimiters, [message] the engine's error when it gave one, and [displayMode]
 * is `false` for inline `$...$` and `true` for block `$$...$$`.
 */
data class LatexErrorEvent(
  val source: String,
  val message: String?,
  val displayMode: Boolean,
)
