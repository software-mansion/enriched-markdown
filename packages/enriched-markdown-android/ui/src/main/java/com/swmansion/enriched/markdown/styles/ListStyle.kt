package com.swmansion.enriched.markdown.styles

data class ListStyle(
  override val fontSize: Float,
  override val fontFamily: String,
  override val fontWeight: String,
  override val color: Int,
  override val marginTop: Float,
  override val marginBottom: Float,
  override val lineHeight: Float,
  val bulletColor: Int,
  val bulletSize: Float,
  val markerMinWidth: Float,
  val markerColor: Int,
  val markerFontWeight: String,
  val gapWidth: Float,
  val marginLeft: Float,
) : BaseBlockStyle {
  fun effectiveMarkerWidth(naturalWidth: Float): Float = naturalWidth.coerceAtLeast(markerMinWidth)
}
