package com.swmansion.enriched.markdown.styles

data class CodeBlockStyle(
  override val fontSize: Float,
  override val fontFamily: String,
  override val fontWeight: String,
  override val color: Int,
  override val marginTop: Float,
  override val marginBottom: Float,
  override val lineHeight: Float,
  val backgroundColor: Int,
  val borderColor: Int,
  val borderRadius: Float,
  val borderWidth: Float,
  val padding: Float,
) : BaseBlockStyle
