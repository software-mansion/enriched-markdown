package com.swmansion.enriched.markdown.styles

/**
 * Style for underline runs.
 *
 * Underline nodes are only produced when the parser runs with
 * [com.swmansion.enriched.markdown.parser.Md4cFlags.underline] enabled — otherwise `_text_`
 * and `__text__` stay emphasis and strong.
 *
 * [color] overrides the text color of the underlined run; `null` inherits the color of the
 * surrounding block. Android draws the underline in the text color, so this is the line
 * color too.
 */
data class UnderlineStyle(
  val color: Int? = null,
)
