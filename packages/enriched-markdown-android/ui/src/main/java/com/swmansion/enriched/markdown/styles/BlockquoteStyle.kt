package com.swmansion.enriched.markdown.styles

/**
 * Per-admonition-type colors.
 *
 * [color] tints the accent bar, the header title and the header icon; [backgroundColor] `null`
 * (or a fully transparent color) means the box is not filled.
 */
data class AdmonitionColors(
  val color: Int,
  val backgroundColor: Int? = null,
)

data class BlockquoteStyle(
  override val fontSize: Float,
  override val fontFamily: String,
  override val fontWeight: String,
  override val color: Int,
  override val marginTop: Float,
  override val marginBottom: Float,
  override val lineHeight: Float,
  val borderColor: Int,
  val borderWidth: Float,
  val gapWidth: Float,
  val backgroundColor: Int?,
  val borderRadius: Float = 0f,
  val padding: Float = 0f,
  /**
   * GitHub alert palette keyed by admonition type ("note", "tip", "important", "warning",
   * "caution"). A type missing from the map falls back to the plain blockquote colors, so an
   * empty map renders every admonition as an ordinary quote with a header.
   */
  val admonitions: Map<String, AdmonitionColors> = emptyMap(),
) : BaseBlockStyle
