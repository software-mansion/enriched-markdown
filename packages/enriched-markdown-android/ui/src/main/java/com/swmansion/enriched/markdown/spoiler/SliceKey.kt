package com.swmansion.enriched.markdown.spoiler

import com.swmansion.enriched.markdown.spans.SpoilerSpan

/**
 * A spoiler slice keeps its overlay while its layout line and characters stay the same, even if it
 * moves or resizes. [start] and [end] are the part of [span] on layout line [line], not the span's
 * own range.
 */
internal data class SliceKey(
  val span: SpoilerSpan,
  val line: Int,
  val start: Int,
  val end: Int,
)

internal data class SliceRect(
  val left: Float,
  val top: Float,
  val width: Float,
  val height: Float,
)
