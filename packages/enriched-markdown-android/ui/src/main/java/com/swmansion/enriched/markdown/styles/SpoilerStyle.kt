package com.swmansion.enriched.markdown.styles

/**
 * Colors of the spoiler overlay; the effect itself is set by
 * [com.swmansion.enriched.markdown.spoiler.SpoilerOverlay].
 *
 * @property color the particles' color, and the solid overlay's fill.
 */
data class SpoilerStyle(
  val color: Int = DEFAULT_COLOR,
) {
  companion object {
    internal const val DEFAULT_COLOR = 0xFF374151.toInt()
  }
}
