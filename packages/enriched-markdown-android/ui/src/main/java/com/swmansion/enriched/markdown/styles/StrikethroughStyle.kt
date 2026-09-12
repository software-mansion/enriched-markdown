package com.swmansion.enriched.markdown.styles

/**
 * Style for `~~strikethrough~~` runs.
 *
 * [color] overrides the text color of the struck run; `null` inherits the color of the
 * surrounding block. Android draws the strikethrough line in the text color, so this is
 * the line color too.
 */
data class StrikethroughStyle(
  val color: Int? = null,
)
