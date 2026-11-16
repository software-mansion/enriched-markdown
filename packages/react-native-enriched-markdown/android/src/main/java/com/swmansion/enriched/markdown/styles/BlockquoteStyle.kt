package com.swmansion.enriched.markdown.styles

import com.facebook.react.bridge.ReadableMap
import com.swmansion.enriched.markdown.segments.AdmonitionIcons

/** Per-admonition-type look. [color] tints border/title/icon; [backgroundColor] null = transparent; empty [title] = icon only. */
data class AdmonitionStyle(
  val color: Int,
  val backgroundColor: Int?,
  val title: String,
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
  val borderRadius: Float,
  val padding: Float,
  val admonitions: Map<String, AdmonitionStyle>,
) : BaseBlockStyle {
  companion object {
    private fun parseAdmonitions(
      map: ReadableMap,
      parser: StyleParser,
    ): Map<String, AdmonitionStyle> {
      val admonitionsMap = map.getMap("admonitions") ?: return emptyMap()
      val result = mutableMapOf<String, AdmonitionStyle>()
      for (type in AdmonitionIcons.TYPES) {
        val typeMap = admonitionsMap.getMap(type) ?: continue
        result[type] =
          AdmonitionStyle(
            parser.parseColor(typeMap, "color"),
            parser.parseOptionalColor(typeMap, "backgroundColor"),
            parser.parseString(typeMap, "title"),
          )
      }
      return result
    }

    fun fromReadableMap(
      map: ReadableMap,
      parser: StyleParser,
    ): BlockquoteStyle {
      val fontSize = parser.toPixelFromSP(map.getDouble("fontSize").toFloat())
      val fontFamily = parser.parseString(map, "fontFamily")
      val fontWeight = parser.parseString(map, "fontWeight", "normal")
      val color = parser.parseColor(map, "color")
      val marginTop = parser.toPixelFromDIP(map.getDouble("marginTop").toFloat())
      val marginBottom = parser.toPixelFromDIP(map.getDouble("marginBottom").toFloat())
      val lineHeightRaw = map.getDouble("lineHeight").toFloat()
      val lineHeight = parser.toPixelFromSP(lineHeightRaw)
      val borderColor = parser.parseColor(map, "borderColor")
      val borderWidth = parser.toPixelFromDIP(map.getDouble("borderWidth").toFloat())
      val gapWidth = parser.toPixelFromDIP(map.getDouble("gapWidth").toFloat())
      val backgroundColor = parser.parseOptionalColor(map, "backgroundColor")
      val borderRadius = parser.toPixelFromDIP(map.getDouble("borderRadius").toFloat())
      val padding = parser.toPixelFromDIP(map.getDouble("padding").toFloat())
      val admonitions = parseAdmonitions(map, parser)

      return BlockquoteStyle(
        fontSize,
        fontFamily,
        fontWeight,
        color,
        marginTop,
        marginBottom,
        lineHeight,
        borderColor,
        borderWidth,
        gapWidth,
        backgroundColor,
        borderRadius,
        padding,
        admonitions,
      )
    }
  }
}
