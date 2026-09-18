package com.swmansion.enriched.markdown.styles

/**
 * Style for `==highlight==` runs.
 *
 * Highlight nodes are only produced when the parser runs with
 * [com.swmansion.enriched.markdown.parser.Md4cFlags.highlight] enabled — otherwise `==text==`
 * stays literal text.
 *
 * [color] overrides the text color of the highlighted run; `null` inherits the color of the
 * surrounding block. [backgroundColor] is painted behind the run; a fully transparent value
 * leaves the background untouched.
 */
data class HighlightStyle(
  val color: Int? = null,
  val backgroundColor: Int = 0,
)
