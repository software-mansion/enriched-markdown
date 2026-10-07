package com.swmansion.enriched.markdown.styles

/**
 * Style for `==highlight==` runs.
 *
 * Highlight nodes are only produced when the parser runs with
 * [com.swmansion.enriched.markdown.parser.Md4cFlags.highlight] enabled — otherwise `==text==`
 * stays plain text.
 *
 * [color] overrides the text color of the highlighted run; `null` inherits the color of the
 * surrounding block. [backgroundColor] fills the band behind the glyphs; a fully transparent
 * color draws no band.
 */
data class HighlightStyle(
  val color: Int? = null,
  val backgroundColor: Int = DEFAULT_BACKGROUND_COLOR,
) {
  companion object {
    internal const val DEFAULT_BACKGROUND_COLOR = 0xFFFEF08A.toInt()
  }
}
